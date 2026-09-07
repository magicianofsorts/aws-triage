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

- **Event-driven serverless (EventBridge + Lambda)**: Findings arrive unpredictably and in bursts. A long-running server would sit idle most of the time, increasing costs. Lambda scales to zero and fans out automatically.
- **GuardDuty referenced as a data source, not created**: Avoids the "detector already exists" failure and "terraform destroy" won't disable org's threat detection.
- **Claude Haiku 4.5**: Triage is a short classification and explanation task. Frontier models that use more tokens yield similar results as Haiku.
- **DynamoDB**: Serverless storage with cost effective key lookup. RDS would cost more and S3 does not return clean results.
- **PAY_PER_REQUEST billing**: On-demand matches the event-driven pattern and needs zero capacity planning.
- **Single-file zip packaging**: Handler has no third-party dependencies beyond the AWS SDK. A zipped file is simpler than a container image and is faster to iterate.

## Requirements

- **Terraform** >= 1.5
- **AWS CLI**, configured with credentials
- **AWS account permissions** to create/read the resources in the stack:
  IAM role + policy, Lambda, DynamoDB, SNS, EventBridge, CloudWatch Logs, and
  read access to GuardDuty.
- **GuardDuty** already enabled in target region

## Deploy

1. `terraform init`
2. `terraform apply -var="notification_email=you@example.com"`
3. Confirm the SNS subscription email.

## Fire a test finding

    aws guardduty create-sample-findings \
      --detector-id "$(terraform output -raw detector_id)"

Both SNS emails and new DynamoDB items will be processed within a minute.

## Notes

- IAM is scoped to exact resource ARNs (no wildcards) — see `iam.tf`.
- One consistent region across the AWS CLI/provider, GuardDuty, and the
  Bedrock model access grant.
- DynamoDB uses server-side encryption; logs retain 14 days.
