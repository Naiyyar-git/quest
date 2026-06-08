import json
import requests
from bs4 import BeautifulSoup

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

BLS_BASE_URL = "https://download.bls.gov/pub/time.series/pr/"
BLS_PREFIX   = "/pub/time.series/pr/"
USER_AGENT   = "naiyyar@outlook.com - Rearc Data Quest pipeline"

# ─────────────────────────────────────────────
# MAIN HANDLER
# Lambda 1 job — scrape BLS directory
# return filename list to Step Functions
# ─────────────────────────────────────────────

def lambda_handler(event, context):

    print(f"scraping BLS directory: {BLS_BASE_URL}")

    headers = {"User-Agent": USER_AGENT}

    try:
        response = requests.get(BLS_BASE_URL, headers=headers, timeout=15)
        response.raise_for_status()

        soup  = BeautifulSoup(response.text, "html.parser")
        files = []

        for link in soup.find_all("a"):
            href = link.get("href", "")

            # only keep links that are actual data files
            # skip the parent directory link /pub/time.series/
            if href.startswith(BLS_PREFIX) and href != BLS_PREFIX:
                # extract just the filename from the full path
                # e.g. /pub/time.series/pr/pr.data.0.Current → pr.data.0.Current
                filename = href.replace(BLS_PREFIX, "").strip()
                if filename:
                    files.append(filename)

        print(f"found {len(files)} files on BLS page")
        print(json.dumps({"files": files}))

        return {
            "statusCode": 200,
            "files": files,
            "base_url": BLS_BASE_URL,
            "user_agent": USER_AGENT
        }

    except requests.HTTPError as e:
        print(f"HTTP error scraping BLS: {e}")
        raise

    except Exception as e:
        print(f"unexpected error: {e}")
        raise