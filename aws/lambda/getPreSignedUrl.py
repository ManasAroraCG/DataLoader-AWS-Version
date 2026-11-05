import json
import boto3
import os


BUCKET_NAME = "s3-datamig-bucket"
UPLOAD_PREFIX = "uploads/"
PRESIGNED_URL_EXPIRY = 300


def lambda_handler(event, context):
    try:
        body = event.get("body")

        if not body:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "message": "Request body is required"
                })
            }

        data = json.loads(body) if isinstance(body, str) else body

        requested_file_name = data.get("fileName")
        job_tracker_id = data.get("jobTrackerId")

        if not requested_file_name:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "message": "fileName is required"
                })
            }

        if not job_tracker_id:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "message": "jobTrackerId is required"
                })
            }

        # Normalize separators and remove any caller-supplied folder.
        normalized_file_name = requested_file_name.replace("\\", "/")
        safe_file_name = os.path.basename(normalized_file_name)

        if not safe_file_name:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "message": "A valid fileName is required"
                })
            }

        # The expected name can be:
        # originalFile.csv_operation_targetObject
        #
        # Require .csv somewhere in the name, not necessarily at the end.
        if ".csv" not in safe_file_name.lower():
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "message": "The file name must contain .csv"
                })
            }

        key = f"{UPLOAD_PREFIX}{safe_file_name}"

        s3 = boto3.client("s3")

        url = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": BUCKET_NAME,
                "Key": key,
                "ContentType": "text/csv",
                "Metadata": {
                    "job-tracker-id": str(job_tracker_id)
                }
            },
            ExpiresIn=PRESIGNED_URL_EXPIRY
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "presignedUrl": url,
                "objectKey": key
            })
        }

    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({
                "message": "Request body must be valid JSON"
            })
        }

    except Exception as error:
        print(f"Error generating presigned URL: {str(error)}")

        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Failed to generate presigned URL"
            })
        }