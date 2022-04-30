variable "name" {
  type        = string
  description = "Prefix to be used on project parts where prefix is needed"
  default     = "tomorr"
}

variable "private_key_name" {
  type        = string
  description = "Name of the private key to be used for connection to EC2 instances"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets of the VPC that will be created"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "vpc_id" {
  type        = string
  description = "Id of the VPC that the bastion host will be provisioned in"
}

variable "bastion_ami" {
  type        = string
  description = "AMI to be used on bastion hosts"
}
