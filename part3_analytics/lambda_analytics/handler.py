import json
import boto3
import pandas as pd
from io import StringIO, BytesIO
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

S3_BUCKET    = "rearc-quest-naiyyar"
BLS_KEY      = "bronze/bls/pr.data.0.Current"
POP_KEY      = "bronze/api/population.json"
DYNAMO_TABLE = "pipeline_metadata"
REGION       = "us-west-2"

s3     = boto3.client("s3", region_name=REGION)
dynamo = boto3.resource("dynamodb", region_name=REGION).Table(DYNAMO_TABLE)

# ─────────────────────────────────────────────
# HELPER — check if this SQS message was already processed
# idempotency check — prevents duplicate analytics runs
# ─────────────────────────────────────────────

def is_already_processed(message_id):
    try:
        result = dynamo.get_item(Key={"pk": f"MSG#{message_id}"})
        return "Item" in result
    except Exception:
        return False

# ─────────────────────────────────────────────
# HELPER — mark this SQS message as processed
# ─────────────────────────────────────────────

def mark_as_processed(message_id):
    dynamo.put_item(Item={
        "pk":           f"MSG#{message_id}",
        "processed_at": datetime.utcnow().isoformat(),
        "status":       "complete"
    })

# ─────────────────────────────────────────────
# HELPER — load BLS csv from S3 into dataframe
# strips whitespace from all string columns
# this is critical — BLS files have trailing spaces
# ─────────────────────────────────────────────

def load_bls_dataframe():
    response = s3.get_object(Bucket=S3_BUCKET, Key=BLS_KEY)
    content  = response["Body"].read().decode("utf-8")

    # BLS files are tab separated
    df = pd.read_csv(StringIO(content), sep="\t")

    # strip whitespace from all string columns — critical for joins
    df = df.apply(lambda col: col.str.strip() if col.dtype == "object" else col)

    # strip whitespace from column names themselves
    df.columns = df.columns.str.strip()

    # cast year to integer for joining with population data
    df["year"] = df["year"].astype(int)

    print(f"loaded BLS dataframe: {len(df)} rows {list(df.columns)}")
    return df

# ─────────────────────────────────────────────
# HELPER — load population json from S3 into dataframe
# ─────────────────────────────────────────────

def load_population_dataframe():
    response = s3.get_object(Bucket=S3_BUCKET, Key=POP_KEY)
    content  = json.loads(response["Body"].read().decode("utf-8"))

    # records are inside the data key of our envelope
    df = pd.DataFrame(content["data"])

    # cast year to integer — API returns it as float sometimes
    df["Year"] = df["Year"].astype(int)

    # cast population to integer — API returns as float
    df["Population"] = df["Population"].astype(int)

    print(f"loaded population dataframe: {len(df)} rows {list(df.columns)}")
    return df

# ─────────────────────────────────────────────
# REPORT 1
# mean and standard deviation of US population
# for years 2013 to 2018 inclusive
# ─────────────────────────────────────────────

def report_population_stats(pop_df):
    filtered = pop_df[
        (pop_df["Year"] >= 2013) &
        (pop_df["Year"] <= 2018)
    ]

    mean_pop = filtered["Population"].mean()
    std_pop  = filtered["Population"].std()

    result = {
        "report":           "population_stats_2013_2018",
        "mean_population":  round(mean_pop),
        "std_deviation":    round(std_pop),
        "years_included":   sorted(filtered["Year"].tolist())
    }

    print("REPORT 1:")
    print(json.dumps(result, indent=2))
    return result

# ─────────────────────────────────────────────
# REPORT 2
# for every series_id find the best year
# best year = year with highest sum of quarterly values
# ─────────────────────────────────────────────

def report_best_year_per_series(bls_df):
    # cast value to float — BLS stores as string sometimes
    bls_df["value"] = pd.to_numeric(bls_df["value"], errors="coerce")

    # group by series_id and year — sum all quarterly values
    grouped = bls_df.groupby(
        ["series_id", "year"]
    )["value"].sum().reset_index()

    # for each series_id keep only the year with highest sum
    best = grouped.loc[
        grouped.groupby("series_id")["value"].idxmax()
    ].reset_index(drop=True)

    result = {
        "report":       "best_year_per_series",
        "row_count":    len(best),
        "sample_rows":  best.head(5).to_dict(orient="records")
    }

    print("REPORT 2:")
    print(json.dumps(result, indent=2))
    return best

# ─────────────────────────────────────────────
# REPORT 3
# filter BLS to series_id PRS30006032 and period Q01
# left join with population on year
# shows population for that year if available
# ─────────────────────────────────────────────

def report_series_population_join(bls_df, pop_df):
    # filter BLS to specific series and period
    filtered = bls_df[
        (bls_df["series_id"] == "PRS30006032") &
        (bls_df["period"]    == "Q01")
    ].copy()

    # left join on year — keeps all BLS rows
    # population will be null for years not in population dataset
    joined = filtered.merge(
        pop_df[["Year", "Population"]],
        left_on  = "year",
        right_on = "Year",
        how      = "left"
    )

    # cast population to integer where available
    joined["Population"] = joined["Population"].where(
        joined["Population"].isna(),
        joined["Population"].astype("Int64")
    )

    # keep only relevant columns
    joined = joined[["series_id", "year", "period", "value", "Population"]]

    result = {
        "report":      "series_population_join",
        "series_id":   "PRS30006032",
        "period":      "Q01",
        "row_count":   len(joined),
        "sample_rows": joined.head(5).to_dict(orient="records")
    }

    print("REPORT 3:")
    print(json.dumps(result, indent=2, default=str))
    return joined

# ─────────────────────────────────────────────
# MAIN HANDLER
# triggered by SQS when population.json lands in S3
# checks idempotency first
# loads both dataframes
# runs three reports
# logs results to CloudWatch
# ─────────────────────────────────────────────

def lambda_handler(event, context):

    print("lambda 5 analytics triggered")
    print(f"timestamp: {datetime.utcnow().isoformat()}")

    # SQS passes messages as a list — process each one
    for record in event.get("Records", [{"messageId": "local-test"}]):
        message_id = record.get("messageId", "local-test")

        # idempotency check — skip if already processed
        if is_already_processed(message_id):
            print(f"message {message_id} already processed — skipping")
            continue

        try:
            # load both dataframes from S3
            bls_df = load_bls_dataframe()
            pop_df = load_population_dataframe()

            # run all three reports
            report_1 = report_population_stats(pop_df)
            report_2 = report_best_year_per_series(bls_df)
            report_3 = report_series_population_join(bls_df, pop_df)

            # mark message as processed in dynamodb
            mark_as_processed(message_id)

            print(json.dumps({
                "status":     "success",
                "message_id": message_id,
                "timestamp":  datetime.utcnow().isoformat()
            }))

        except Exception as e:
            print(f"error running analytics: {e}")
            raise

    return {"statusCode": 200, "body": "analytics complete"}