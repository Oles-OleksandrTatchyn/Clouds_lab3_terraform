import json
import boto3
import os
import uuid
import re
from datetime import datetime, timezone

TABLE_NAME = os.environ.get("TABLE_NAME")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")
LOG_BUCKET = os.environ.get("LOG_BUCKET")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)
sns_client = boto3.client("sns")
s3_client = boto3.client("s3")
# Comprehend client created at module level (INIT phase) — reused on warm starts
comprehend = boto3.client("comprehend", region_name="eu-central-1")

def log_to_s3(method, path, status_code, body=None):
    if not LOG_BUCKET:
        return
    try:
        timestamp = datetime.now(timezone.utc).isoformat()
        log_entry = {
            "timestamp": timestamp,
            "method": method,
            "path": path,
            "status_code": status_code,
            "body": body,
        }
        key = f"logs/{datetime.now(timezone.utc).strftime('%Y/%m/%d')}/{uuid.uuid4()}.json"
        s3_client.put_object(
            Bucket=LOG_BUCKET,
            Key=key,
            Body=json.dumps(log_entry),
            ContentType="application/json",
        )
    except Exception as e:
        print(f"S3 logging error: {e}")


def detect_language(text):
    """Detect dominant language of text via Amazon Comprehend.
    Returns dict with language_code and confidence, or None on failure."""
    try:
        result = comprehend.detect_dominant_language(Text=text)
        languages = result.get("Languages", [])
        if not languages:
            return None
        # Pick language with highest Score
        top = max(languages, key=lambda x: x["Score"])
        return {
            "language_code": top["LanguageCode"],
            "confidence": round(top["Score"], 4),
        }
    except Exception as e:
        print(f"Comprehend error: {e}")
        return None


def handler(event, context):
    http_method = event.get("requestContext", {}).get("http", {}).get("method") or \
                  event.get("requestContext", {}).get("httpMethod", "")
    raw_path = event.get("rawPath") or event.get("path", "/")
    path_params = event.get("pathParameters") or {}

    print(f"Method: {http_method}, Path: {raw_path}")

    try:
        # POST /registrations — register participant, save to DynamoDB, send SNS
        if http_method == "POST" and re.match(r"^/registrations/?$", raw_path):
            body = json.loads(event.get("body") or "{}")
            name = body.get("name")
            email = body.get("email")
            event_id = body.get("event_id")

            if not name or not email or not event_id:
                log_to_s3(http_method, raw_path, 400)
                return _response(400, {"message": "name, email and event_id are required"})

            participant_id = str(uuid.uuid4())
            registered_at = datetime.now(timezone.utc).isoformat()

            # Detect dominant language of the name field (AI enrichment)
            lang_result = detect_language(name)

            item = {
                "id": participant_id,
                "event_id": event_id,
                "name": name,
                "email": email,
                "registered_at": registered_at,
            }
            if lang_result:
                item["language_code"] = lang_result["language_code"]
                item["language_confidence"] = str(lang_result["confidence"])

            table.put_item(Item=item)

            # Choose confirmation language based on detected language
            if lang_result and lang_result["language_code"] == "uk":
                subject = f"Підтвердження реєстрації — Захід {event_id}"
                message = (
                    f"Вітаємо, {name}!\n\n"
                    f"Вашу реєстрацію на захід '{event_id}' підтверджено.\n"
                    f"ID реєстрації: {participant_id}\n"
                    f"Час: {registered_at}"
                )
            else:
                subject = f"Registration Confirmation — Event {event_id}"
                message = (
                    f"Hello {name}!\n\n"
                    f"You have been successfully registered for event '{event_id}'.\n"
                    f"Registration ID: {participant_id}\n"
                    f"Time: {registered_at}"
                )

            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=subject,
                Message=message,
            )

            log_to_s3(http_method, raw_path, 201, item)
            return _response(201, {
                "id": participant_id,
                "event_id": event_id,
                "registered_at": registered_at,
                "notification": "sent",
                "language": lang_result,
            })

        # GET /registrations/{id}/lang — return detected language for a registration
        if http_method == "GET" and re.match(r"^/registrations/[^/]+/lang/?$", raw_path):
            registration_id = path_params.get("id") or raw_path.split("/")[2]

            result = table.get_item(Key={"id": registration_id})
            item = result.get("Item")

            if not item:
                log_to_s3(http_method, raw_path, 404)
                return _response(404, {"message": "Registration not found"})

            # If language was not stored at registration time, detect it now
            if "language_code" not in item:
                lang_result = detect_language(item.get("name", ""))
                if lang_result:
                    table.update_item(
                        Key={"id": registration_id},
                        UpdateExpression="SET language_code = :lc, language_confidence = :ls",
                        ExpressionAttributeValues={
                            ":lc": lang_result["language_code"],
                            ":ls": str(lang_result["confidence"]),
                        },
                    )
                    item["language_code"] = lang_result["language_code"]
                    item["language_confidence"] = str(lang_result["confidence"])

            log_to_s3(http_method, raw_path, 200)
            return _response(200, {
                "id": registration_id,
                "name": item.get("name"),
                "language_code": item.get("language_code"),
                "language_confidence": item.get("language_confidence"),
            })

        # GET /registrations/{event_id}/count — return participant count
        if http_method == "GET" and re.match(r"^/registrations/[^/]+/count/?$", raw_path):
            event_id = path_params.get("event_id") or raw_path.split("/")[2]

            response = table.query(
                IndexName="event_id-index",
                KeyConditionExpression=boto3.dynamodb.conditions.Key("event_id").eq(event_id),
                Select="COUNT",
            )
            count = response.get("Count", 0)

            log_to_s3(http_method, raw_path, 200)
            return _response(200, {"event_id": event_id, "count": count})

        # GET /registrations/{event_id} — list participants for event
        if http_method == "GET" and re.match(r"^/registrations/[^/]+/?$", raw_path):
            event_id = path_params.get("event_id") or raw_path.split("/")[2]

            response = table.query(
                IndexName="event_id-index",
                KeyConditionExpression=boto3.dynamodb.conditions.Key("event_id").eq(event_id),
            )
            items = response.get("Items", [])

            log_to_s3(http_method, raw_path, 200)
            return _response(200, {"event_id": event_id, "participants": items})

        log_to_s3(http_method, raw_path, 404)
        return _response(404, {"message": "Not Found"})

    except Exception as e:
        print(f"Error: {e}")
        log_to_s3(http_method, raw_path, 500)
        return _response(500, {"message": "Internal Server Error"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str),
    }
