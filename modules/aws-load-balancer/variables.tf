variable "vpc_id" {
  type        = string
  description = "Id of the VPC that the bastion host will be provisioned in"
}

variable "name" {
  type        = string
  description = "Prefix to be used on project parts where prefix is needed"
  default     = "tomorr"
}

variable "instance_port" {
  type        = number
  description = "Port where the application is deployed on the instances"
  default     = 8098
}

variable "subnets" {
  type        = list(string)
  description = "Subnets to be attached to the VPC"
}

variable "environment" {
  type        = string
  description = "Environment name"
}
