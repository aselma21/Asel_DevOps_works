variable "stage" {
  type = string
  validation {
    condition = contains(["dev", "prod"], var.stage)
    error_message = "Stage must be either dev or prod."
  }
}

variable "trusted_account_number" {
  type = string
}

variable "developer_role" {
  type = string
}

variable "devops_role" {
  type = string
}

variable "developer_policy" {
  type = string
}

variable "devops_policy" {
  type = string
}
