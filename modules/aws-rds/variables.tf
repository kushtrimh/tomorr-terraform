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
  description = "RDS instance port"
  default     = 5432
}

variable "username" {
  type        = string
  description = "RDS instance username"
  default     = "tomorrdev"
}

variable "password" {
  type        = string
  description = "RDS instance password"
  sensitive   = true
}

variable "parameter_group_name" {
  type        = string
  description = "RDS instance parameter group name"
  default     = "default.postgres13"
}

variable "db_name" {
  type        = string
  description = "RDS database name"
  default     = "postgres"
}

variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "Subnets CIDR blocks, to be used to allow traffic from to the RDS instance"
}
