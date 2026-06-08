import json
import boto3
import requests
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

S3_BUCKET    = "rearc-quest-naiyyar"
S3_PREFIX    = "bronze/bls/"
DYNAMO_TABLE = "pipeline_metadata"
REGION       = "us-west-2"
USER_AGENT   = "naiyyar@outlook.com - Rearc Data Quest pipeline"

s3     = boto3.client("s3", region_name=REGION)
dynamo = boto3.resource("dynamodb", region_name=REGION).Table(DYNAMO_TABLE)

# ─────────────────────────────────────────────
# HELPER — download file from BLS with retry
# retries up to 3 times on rate limit (429)
# fails immediately on 403 or 404
# ─────────────────────────────────────────────

def download_file(url, user_agent, max_attempts=3):
    headers = {"User-Agent": user_agent}
    import time

    for attempt in range(max_attempts):
        response = requests.get(url, headers=headers, timeout=30)

        if response.status_code == 429:
            # rate limited — wait and retry
            wait = 2 ** attempt
            print(f"rate limited on {url} waiting {wait}s")
            time.sleep(wait)
            continue

        response.raise_for_status()
        return response

    raise Exception(f"failed to download {url} after {max_attempts} attempts")

# ─────────────────────────────────────────────
# HELPER — upload file bytes to S3
# ─────────────────────────────────────────────

def upload_to_s3(filename, content):
    s3_key = S3_PREFIX + filename
    s3.put_object(
        Bucket = S3_BUCKET,
        Key    = s3_key,
        Body   = content
    )
    print(f"uploaded to s3://{S3_BUCKET}/{s3_key}")
    return s3_key

# ─────────────────────────────────────────────
# HELPER — save new etag to dynamodb
# ─────────────────────────────────────────────

def save_etag(filename, etag, s3_key):
    dynamo.put_item(Item={
        "pk":            f"FILE#{filename}",
        "etag":          etag,
        "s3_key":        s3_key,
        "last_synced_at": datetime.utcnow().isoformat()
    })
    print(f"saved etag for {filename} to dynamodb")

# ─────────────────────────────────────────────
# MAIN HANDLER
# receives changed files list from Lambda 2
# downloads each file and uploads to S3
# updates dynamodb etag after each successful upload
# ─────────────────────────────────────────────

def lambda_handler(event, context):

    # Step Functions passes Lambda 2 output as event
    changed_files = event.get("changed_files", [])
    user_agent    = event.get("user_agent", USER_AGENT)

    print(f"syncing {len(changed_files)} changed files to S3")

    results = {
        "success": [],
        "failed":  []
    }

    for file_info in changed_files:
        filename   = file_info["filename"]
        url        = file_info["url"]
        remote_etag = file_info["remote_etag"]

        try:
            # download file from BLS
            print(f"downloading: {filename}")
            response = download_file(url, user_agent)

            # upload raw bytes to S3 bronze layer
            s3_key = upload_to_s3(filename, response.content)

            # save new etag to dynamodb
            save_etag(filename, remote_etag, s3_key)

            results["success"].append(filename)

        except Exception as e:
            # one file failing never stops the rest
            print(f"error syncing {filename}: {e}")
            results["failed"].append({
                "filename": filename,
                "error":    str(e)
            })
            continue

    # log final summary
    print(json.dumps({
        "run_summary": results,
        "timestamp":   datetime.utcnow().isoformat(),
        "success":     len(results["success"]),
        "failed":      len(results["failed"])
    }))

    return {
        "statusCode": 200,
        "results":    results
    }