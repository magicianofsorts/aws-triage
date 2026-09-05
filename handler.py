import json
import os

import boto3
from botocore.exceptions import ClientError

MODEL_ID = os.environ["MODEL_ID"]
TABLE_NAME = os.environ["TABLE_NAME"]
TOPIC_ARN = os.environ["TOPIC_ARN"]

bedrock = boto3.client("bedrock-runtime")
table = boto3.resource("dynamodb").Table(TABLE_NAME)
sns = boto3.client("sns")

PROMPT_TEMPLATE = """You are a cloud security analyst triaging an AWS GuardDuty finding.

Finding:
{finding}

Respond with ONLY a JSON object, no prose, no markdown fences, with exactly these keys:
- "summary": one plain-English sentence describing what happened
- "risk_score": integer 1-10 (10 = most severe)
- "reasoning": one sentence justifying the score
- "remediation": one concrete recommended action
"""


def triage(finding: dict) -> dict:
    """Call Bedrock and return the parsed triage JSON."""
    prompt = PROMPT_TEMPLATE.format(finding=json.dumps(finding, indent=2))

    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 512,
        "messages": [{"role": "user", "content": prompt}],
    }

    resp = bedrock.invoke_model(modelId=MODEL_ID, body=json.dumps(body))
    payload = json.loads(resp["body"].read())
    text = payload["content"][0]["text"].strip()

    if text.startswith("```"):
        text = text.split("```")[1].lstrip("json").strip()
    return json.loads(text)


def handler(event, _context):
    finding = event.get("detail", event)
    finding_id = finding.get("id", "unknown")
    severity = finding.get("severity", "n/a")
    title = finding.get("title", finding.get("type", "GuardDuty finding"))

    try:
        result = triage(finding)
    except (ClientError, KeyError, json.JSONDecodeError) as exc:
        print(f"Triage failed for {finding_id}: {exc}")
        result = {
            "summary": title,
            "risk_score": 0,
            "reasoning": f"Automated triage failed: {exc}",
            "remediation": "Review this finding manually.",
        }

    item = {
        "finding_id": finding_id,
        "title": title,
        "guardduty_severity": str(severity),
        "risk_score": result["risk_score"],
        "summary": result["summary"],
        "reasoning": result["reasoning"],
        "remediation": result["remediation"],
    }
    table.put_item(Item=item)

    message = (
        f"[{result['risk_score']}/10] {result['summary']}\n\n"
        f"Why: {result['reasoning']}\n"
        f"Fix: {result['remediation']}\n\n"
        f"Finding ID: {finding_id} (GuardDuty severity {severity})"
    )
    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject=f"[Triage {result['risk_score']}/10] {title}"[:100],
        Message=message,
    )

    return {"finding_id": finding_id, "risk_score": result["risk_score"]}
