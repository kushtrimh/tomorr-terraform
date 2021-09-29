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

variable "rds_cidr" {
  type        = string
  description = "CIDR used for ingress in RDS instance"
}
