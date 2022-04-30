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

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets of the VPC that will be created"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "environment" {
  type        = string
  description = "Environment name"
}
