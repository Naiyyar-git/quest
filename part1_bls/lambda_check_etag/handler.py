import json
import boto3
import requests

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

DYNAMO_TABLE = "pipeline_metadata"
REGION       = "us-west-2"
USER_AGENT   = "naiyyar@outlook.com - Rearc Data Quest pipeline"

dynamo = boto3.resource("dynamodb", region_name=REGION).Table(DYNAMO_TABLE)

# ─────────────────────────────────────────────
# HELPER — get stored etag from dynamodb
# returns None if file has never been downloaded
# ─────────────────────────────────────────────

def get_stored_etag(filename):
    result = dynamo.get_item(Key={"pk": f"FILE#{filename}"})
    return result.get("Item", {}).get("etag", None)

# ─────────────────────────────────────────────
# HELPER — get current etag from BLS server
# sends HEAD request — no download needed
# ─────────────────────────────────────────────

def get_remote_etag(url):
    headers  = {"User-Agent": USER_AGENT}
    response = requests.head(url, headers=headers, timeout=10)
    response.raise_for_status()
    return response.headers.get("ETag", "").strip('"')

# ─────────────────────────────────────────────
# MAIN HANDLER
# receives file list from Lambda 1 via Step Functions
# checks each file etag against dynamodb
# returns only changed or new files
# ─────────────────────────────────────────────

def lambda_handler(event, context):

    # Step Functions passes Lambda 1 output as event
    files    = event.get("files", [])
    base_url = event.get("base_url", "")
    user_agent = event.get("user_agent", USER_AGENT)

    print(f"checking {len(files)} files against dynamodb")

    changed_files = []
    skipped_files = []

    for filename in files:
        try:
            url = base_url + filename

            # get fingerprint from bls server
            remote_etag = get_remote_etag(url)

            # get fingerprint we stored last time
            stored_etag = get_stored_etag(filename)

            if remote_etag and remote_etag == stored_etag:
                # file has not changed — skip it
                print(f"skipped (unchanged): {filename}")
                skipped_files.append(filename)
            else:
                # file is new or changed — add to download list
                print(f"changed or new: {filename}")
                changed_files.append({
                    "filename":   filename,
                    "url":        url,
                    "remote_etag": remote_etag
                })

        except Exception as e:
            print(f"error checking {filename}: {e}")
            # do not stop — move to next file
            continue

    print(f"changed: {len(changed_files)} skipped: {len(skipped_files)}")

    # return changed files list to Step Functions
    # Step Functions passes this to Lambda 3
    return {
        "statusCode":    200,
        "changed_files": changed_files,
        "skipped_files": skipped_files,
        "user_agent":    USER_AGENT
    }