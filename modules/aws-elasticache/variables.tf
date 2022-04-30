variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "Subnets CIDR blocks, to be used to allow traffic from to the RDS instance"
}

variable "parameter_group_name" {
  type        = string
  description = "Elasticache instance parameter group name"
}

variable "vpc_id" {
  type        = string
  description = "Id of the VPC that the bastion host will be provisioned in"
}

variable "name" {
  type        = string
  description = "Prefix to be used on project parts where prefix is needed"
  default     = "tomorr"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets of the VPC that will be created"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "port" {
  type        = number
  description = "Elasticache instance port"
  default     = 6379
}
