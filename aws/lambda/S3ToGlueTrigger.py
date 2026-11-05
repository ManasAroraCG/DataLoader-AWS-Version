
import boto3
import logging
import urllib.parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)

GLUE_JOB_NAME = "CSVProcessingJob"

def lambda_handler(event, context):
    glue = boto3.client('glue')
    s3 = boto3.client('s3')

    record = event['Records'][0]

    bucket = record['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(record['s3']['object']['key'])

    # Retrieve Job Tracker ID from S3 object metadata
    metadata_response = s3.head_object(
        Bucket=bucket,
        Key=key
    )

    job_tracker_id = metadata_response.get(
        'Metadata', {}
    ).get('job-tracker-id')

    if not job_tracker_id:
        raise ValueError(
            f"Job Tracker ID not found in S3 metadata for {key}"
        )

    logger.info(f"Job Tracker ID: {job_tracker_id}")

    # Start Glue and pass the existing Salesforce Job Tracker ID
    response = glue.start_job_run(
        JobName=GLUE_JOB_NAME,
        Arguments={
            '--bucket': bucket,
            '--key': key,
            '--job_tracker_id': job_tracker_id
        }
    )

    logger.info(
        f"Started Glue job {GLUE_JOB_NAME} "
        f"for {bucket}/{key}: {response['JobRunId']}"
    )

    return {
        "statusCode": 200,
        "body": f"Started Glue job for {bucket}/{key}"
    }
