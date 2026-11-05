import sys
import json
import urllib.parse
import logging
import boto3
import csv
import io
import os
import requests
import pandas as pd
import time

from botocore.exceptions import ClientError
from awsglue.utils import getResolvedOptions

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# --------------------------------------------------
# 1. Get Salesforce credentials
# --------------------------------------------------

def get_salesforce_secrets():
    secret_name = "salesforce/dataMigration"
    region_name = "us-east-1"

    session = boto3.session.Session()

    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    secret_dict = json.loads(
        get_secret_value_response['SecretString']
    )

    client_id = secret_dict['client_id']
    client_secret = secret_dict['client_secret']
    refresh_token = secret_dict['refresh_token']

    return client_id, client_secret, refresh_token


# --------------------------------------------------
# 2. Receive Glue arguments
# --------------------------------------------------

args = getResolvedOptions(
    sys.argv,
    ['bucket', 'key', 'job_tracker_id']
)

bucket = args['bucket']
raw_key = args['key']
job_tracker_id = args['job_tracker_id']

logger.info(f"Received Job Tracker ID: {job_tracker_id}")


# --------------------------------------------------
# 3. Salesforce authentication
# --------------------------------------------------

client_id, client_secret, refresh_token = get_salesforce_secrets()


def get_access_token(client_id, client_secret, refresh_token):
    url = 'https://login.salesforce.com/services/oauth2/token'

    data = {
        'grant_type': 'refresh_token',
        'client_id': client_id,
        'client_secret': client_secret,
        'refresh_token': refresh_token
    }

    response = requests.post(url, data=data)
    response.raise_for_status()

    return response.json()


response = get_access_token(
    client_id,
    client_secret,
    refresh_token
)

instance_url = response['instance_url']
access_token = response['access_token']


# --------------------------------------------------
# 4. Process S3 filename
# --------------------------------------------------

key = urllib.parse.unquote_plus(raw_key).split('?', 1)[0]

print("key", key)

file_name = os.path.basename(key)

parts = file_name.split('_', 2)

print(parts)

file_name = parts[0]
print(f"Derived file_name: {file_name}")

operation_type = parts[1]
print(f"Derived operation_type: {operation_type}")

target_object = parts[2]
print(f"Derived target_object: {target_object}")


# --------------------------------------------------
# 5. Read CSV from S3
# --------------------------------------------------

s3 = boto3.client('s3')

obj = s3.get_object(
    Bucket=bucket,
    Key=key
)

csv_content = obj['Body'].read().decode('utf-8')


# --------------------------------------------------
# 6. Salesforce Bulk API functions
# --------------------------------------------------

def create_job(
    instance_url,
    access_token,
    object_type='CgInfinity__Data_Feed_Record__c'
):
    url = f"{instance_url}/services/data/v65.0/jobs/ingest"

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    payload = {
        "object": object_type,
        "contentType": "CSV",
        "operation": "insert"
    }

    response = requests.post(
        url,
        headers=headers,
        json=payload
    )

    print("CREATE JOB STATUS:", response.status_code)
    print("CREATE JOB RESPONSE:", response.text)

    response.raise_for_status()

    return response.json()


def upload_data(
    instance_url,
    access_token,
    job_id,
    file_path
):
    url = (
        f"{instance_url}/services/data/v65.0/"
        f"jobs/ingest/{job_id}/batches"
    )

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "text/csv"
    }

    with open(file_path, 'rb') as f:
        response = requests.put(
            url,
            headers=headers,
            data=f
        )

        response.raise_for_status()

    return response.status_code == 201


def close_job(instance_url, access_token, job_id):
    url = (
        f"{instance_url}/services/data/v65.0/"
        f"jobs/ingest/{job_id}"
    )

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    payload = {
        "state": "UploadComplete"
    }

    response = requests.patch(
        url,
        headers=headers,
        json=payload
    )

    response.raise_for_status()

    return response.json()


def wait_for_job_completion(
    instance_url,
    access_token,
    job_id,
    max_wait_seconds=300
):
    """Wait for Bulk API job completion with polling."""

    url = (
        f"{instance_url}/services/data/v65.0/"
        f"jobs/ingest/{job_id}"
    )

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    elapsed = 0
    poll_interval = 5

    while elapsed < max_wait_seconds:

        response = requests.get(
            url,
            headers=headers
        )

        response.raise_for_status()

        job_status = response.json()
        state = job_status.get('state')

        logger.info(
            f"Job {job_id} state: {state} "
            f"(elapsed: {elapsed}s)"
        )

        if state in [
            'JobComplete',
            'Completed',
            'Failed',
            'Aborted'
        ]:

            if state in ['Failed', 'Aborted']:
                logger.error(
                    f"Bulk API job {job_id} failed: {state}"
                )

                raise Exception(
                    f"Bulk API job {job_id} failed with state {state}"
                )

            return job_status

        time.sleep(poll_interval)
        elapsed += poll_interval

        if poll_interval < 30:
            poll_interval = min(
                30,
                poll_interval + 5
            )

    raise Exception(
        f"Bulk API job {job_id} did not complete "
        f"within {max_wait_seconds} seconds"
    )


# --------------------------------------------------
# 7. Read CSV and prepare Data Feed Records
# --------------------------------------------------

reader = csv.DictReader(io.StringIO(csv_content))

records = []

for row in reader:

    records.append({
        "CgInfinity__Data_Feed_Record_JSON__c":
            json.dumps(row, ensure_ascii=False),

        "CgInfinity__File_Name__c":
            file_name,

        # Associate every record with the existing Job Tracker
        "CgInfinity__Data_Feed_Job_Tracker__c":
            job_tracker_id
    })


df = pd.DataFrame(records)

BULK_CHUNK_SIZE = 150000

total_records = len(df)

logger.info(
    f"Total records to upload: {total_records}"
)


# --------------------------------------------------
# 8. Upload records using Salesforce Bulk API 2.0
# --------------------------------------------------

job_ids = []

for i in range(0, total_records, BULK_CHUNK_SIZE):

    chunk_df = df.iloc[i:i + BULK_CHUNK_SIZE]

    chunk_file = (
        f"/tmp/data_feed_bulk_{i // BULK_CHUNK_SIZE + 1}.csv"
    )

    chunk_df.to_csv(
        chunk_file,
        index=False
    )

    # Create Bulk API job
    job = create_job(
        instance_url,
        access_token,
        object_type='CgInfinity__Data_Feed_Record__c'
    )

    job_id = job['id']

    job_ids.append(job_id)

    logger.info(
        f"Created job {job_id} for records "
        f"{i + 1} to {min(i + BULK_CHUNK_SIZE, total_records)}"
    )

    # Upload records
    upload_data(
        instance_url,
        access_token,
        job_id,
        chunk_file
    )

    logger.info(
        f"Uploaded chunk {i // BULK_CHUNK_SIZE + 1}"
    )

    # Close job
    close_job(
        instance_url,
        access_token,
        job_id
    )

    logger.info(
        f"Closed job {job_id}"
    )


# --------------------------------------------------
# 9. Wait for all Bulk API jobs to complete
# --------------------------------------------------

logger.info(
    "Waiting for all Bulk API jobs to complete..."
)

for job_id in job_ids:

    try:

        final_status = wait_for_job_completion(
            instance_url,
            access_token,
            job_id,
            max_wait_seconds=600
        )

        logger.info(
            f"Job {job_id} completed successfully. "
            f"Records: {final_status.get('numberRecordsProcessed', 0)} processed, "
            f"{final_status.get('numberRecordsFailed', 0)} failed"
        )

    except Exception as e:

        logger.error(
            f"Error waiting for job {job_id}: {str(e)}"
        )

        raise


# --------------------------------------------------
# 10. Wait for Salesforce records to become searchable
# --------------------------------------------------

logger.info(
    "Waiting 15 seconds for Salesforce to fully commit records..."
)

time.sleep(15)


# --------------------------------------------------
# 11. Update the EXISTING Job Tracker
# --------------------------------------------------

endpoint_job_tracker = (
    f"{instance_url}/services/data/v65.0/"
    f"sobjects/CgInfinity__Data_Feed_Job_Tracker__c/"
    f"{job_tracker_id}"
)

job_tracker_record = {
    "CgInfinity__Status__c": "Upload Complete"
}

job_tracker_headers = {
    'Authorization': f'Bearer {access_token}',
    'Content-Type': 'application/json'
}

try:

    tracker_response = requests.patch(
        endpoint_job_tracker,
        headers=job_tracker_headers,
        json=job_tracker_record
    )

    logger.info(
        f"Job Tracker Update Status: "
        f"{tracker_response.status_code}"
    )

    if tracker_response.status_code != 204:

        logger.error(
            f"Job Tracker Update Error: "
            f"{tracker_response.text}"
        )

        tracker_response.raise_for_status()

    logger.info(
        f"Existing Job Tracker {job_tracker_id} "
        f"updated to Upload Complete"
    )

except requests.exceptions.RequestException as e:

    logger.error(
        f"Job Tracker Update Failed: {str(e)}"
    )

    raise
