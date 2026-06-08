import json
import boto3
import requests
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

API_URL      = "https://honolulu-api.datausa.io/tesseract/data.jsonrecords?cube=acs_yg_total_population_1&drilldowns=Year%2CNation&locale=en&measures=Population"
S3_BUCKET    = "rearc-quest-naiyyar"
S3_KEY       = "bronze/api/population.json"
REGION       = "us-west-2"
USER_AGENT   = "naiyyar@outlook.com - Rearc Data Quest pipeline"

s3 = boto3.client("s3", region_name=REGION)

# ─────────────────────────────────────────────
# HELPER — fetch all pages from API
# handles pagination automatically
# this API returns one page today
# but loop handles multiple pages if that changes
# ─────────────────────────────────────────────

def fetch_all_pages(url):
    headers  = {"User-Agent": USER_AGENT}
    all_data = []
    page_num = 0

    while url:
        page_num += 1
        print(f"fetching page {page_num}: {url}")

        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()

        body    = response.json()
        # API returns records under "data" key
        records = body.get("data", [])
        all_data.extend(records)

        print(f"got {len(records)} records on page {page_num}")

        # check for next page link
        # handles common pagination patterns
        next_url = (
            body.get("next") or
            body.get("links", {}).get("next")
        )
        url = next_url

    print(f"total records fetched: {len(all_data)}")
    return all_data

# ─────────────────────────────────────────────
# HELPER — save records to S3 as JSON
# always overwrites same key — idempotent by design
# ─────────────────────────────────────────────

def save_to_s3(records):
    payload = {
        "source":       "datausa.io population API",
        "fetched_at":   datetime.utcnow().isoformat(),
        "record_count": len(records),
        "data":         records
    }

    json_bytes = json.dumps(payload, indent=2).encode("utf-8")

    s3.put_object(
        Bucket      = S3_BUCKET,
        Key         = S3_KEY,
        Body        = json_bytes,
        ContentType = "application/json"
    )

    print(f"saved {len(records)} records to s3://{S3_BUCKET}/{S3_KEY}")

# ─────────────────────────────────────────────
# MAIN HANDLER
# Lambda 4 job — fetch population API
# save JSON to S3
# S3 write triggers SQS notification automatically
# which triggers Lambda 5 analytics
# ─────────────────────────────────────────────

def lambda_handler(event, context):

    print("starting population API fetch")

    try:
        # fetch all records — handles pagination
        records = fetch_all_pages(API_URL)

        if not records:
            print("warning: API returned 0 records — nothing saved")
            return {"statusCode": 204, "body": "no records returned"}

        # save to S3 — this write triggers SQS via S3 event notification
        save_to_s3(records)

        print(json.dumps({
            "status":       "success",
            "record_count": len(records),
            "s3_path":      f"s3://{S3_BUCKET}/{S3_KEY}",
            "timestamp":    datetime.utcnow().isoformat()
        }))

        return {
            "statusCode":   200,
            "record_count": len(records),
            "s3_path":      f"s3://{S3_BUCKET}/{S3_KEY}"
        }

    except requests.HTTPError as e:
        print(f"HTTP error fetching population API: {e}")
        raise

    except Exception as e:
        print(f"unexpected error: {e}")
        raise