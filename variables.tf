variable "region" {
  description = "AWS region (must have GuardDuty + Bedrock available)"
  type        = string
  default     = "us-east-1"
}

variable "model_id" {
  description = "Bedrock model ID to invoke for triage"
  type        = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "notification_email" {
  description = "Email address to subscribe to the SNS alerts topic"
  type        = string
}

variable "project" {
  description = "Name prefix for tagging/naming resources"
  type        = string
  default     = "ai-triage"
}
