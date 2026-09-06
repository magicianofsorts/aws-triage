# AI-Powered GuardDuty Findings Triage Pipeline

Event-driven AWS pipeline that uses Amazon Bedrock to auto-triage GuardDuty
findings — summarizing, risk-scoring, and recommending remediations — then
stores each result in DynamoDB and notifies via SNS. Provisioned end-to-end
with Terraform and least-privilege IAM.

## Architecture

GuardDuty finding -> EventBridge rule -> Lambda -> Bedrock (triage)
-> DynamoDB (store)
-> SNS (notify)

### Architecture Decisions

## Deploy

1. `terraform init`
2. `terraform apply -var="notification_email=you@example.com"`
3. Confirm the SNS subscription email.

## Fire a test finding

    aws guardduty create-sample-findings \
      --detector-id "$(terraform output -raw detector_id)"

SNS email and a new DynamoDB item will be processed within a minute.

## Notes

- IAM is scoped to exact resource ARNs (no wildcards) — see `iam.tf`.
- DynamoDB uses server-side encryption; logs retain 14 days.
