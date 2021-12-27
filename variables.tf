variable "environment" {
  type        = string
  description = "Environment name"
}

variable "bastion_ami" {
  type        = string
  description = "AMI to be used on bastion hosts"
}

variable "name_prefix" {
  type        = string
  description = "Prefix to be used on project parts where prefix is needed"
  default     = "tomorr"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to be used"
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets of the VPC that will be created"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}


variable "public_subnets" {
  type        = list(string)
  description = "Public subnets of the VPC that will be created"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "private_key_name" {
  type        = string
  description = "Name of the private key to be used for connection to EC2 instances"
}

variable "rds_port" {
  type        = number
  description = "RDS instance port"
  default     = 5432
}

variable "rds_username" {
  type        = string
  description = "RDS instance username"
  default     = "tomorrdev"
}

variable "rds_password" {
  type        = string
  description = "RDS instance password"
  sensitive   = true
}

variable "rds_parameter_group_name" {
  type        = string
  description = "RDS instance parameter group name"
  default     = "default.postgres13"
}

variable "rds_name" {
  type        = string
  description = "RDS instance name"
  default     = "tomorrdev"
}

variable "cache_parameter_group_name" {
  type        = string
  description = "Cache parameter group name"
  default     = "default.redis6.x"
}

variable "cache_port" {
  type        = number
  description = "Cache port"
  default     = 6379
}

variable "mq_username" {
  type        = string
  description = "MQ username"
  default     = "tomorrmq"
}

variable "mq_password" {
  type        = string
  description = "MQ password"
}

variable "mq_port" {
  type        = number
  description = "MQ port"
  default     = 5671
}

variable "full_repository_id" {
  type        = string
  description = "Full repository id where source changes are to be detected"
  default     = "kushtrimh/tomorr"
}

variable "instance_port" {
  type        = number
  description = "Port where the application is deployed on the instances"
  default     = 8098
}

variable "instance_ami" {
  type        = string
  description = "AMI to use for the application instances"
}
