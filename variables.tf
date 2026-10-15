variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used in resource tags"
  type        = string
  default     = "SZ-terraform-lab"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  description = "Your public IPv4 address in CIDR notation"
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.ssh_allowed_cidr))
    error_message = "Provide a valid IPv4 CIDR, such as your public IP followed by /32."
  }
}