variable "project_id" {
  description = "GCP project ID for production."
  type        = string
}

variable "region" {
  description = "Primary GCP region."
  type        = string
  default     = "us-west1"
}

variable "app_name" {
  description = "Application slug."
  type        = string
  default     = "ai-career-copilot"
}

variable "backend_image" {
  description = "Artifact Registry image URL for the backend."
  type        = string
}

variable "frontend_url" {
  description = "Frontend URL used by the backend for CORS and auth callbacks."
  type        = string
}

variable "app_from_email" {
  description = "Default from email for app notifications."
  type        = string
  default     = "noreply@careermake.ai"
}

variable "app_notify_email" {
  description = "Support inbox for contact and beta feedback notifications."
  type        = string
  default     = "support@careermake.ai"
}
