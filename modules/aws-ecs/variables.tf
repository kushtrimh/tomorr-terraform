variable "vpc_id" {
  type        = string
  description = "VPC where the ECS will be launched"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets that the ASG will use"
}

variable "private_key_name" {
  type        = string
  description = "Private key to be used when connection to EC2 instances"
}

variable "application_ami" {
  type        = string
  description = "AMI to use when deploying the EC2 instances"
}

variable "alb_target_group_arn" {
  type        = string
  description = "ARN of the ALB target group which the ECS service will use"
}

variable "container_name" {
  type        = string
  description = "Name of the deployed containers"
}

variable "container_port" {
  type        = number
  description = "Port that the ALB will use to connect to the containers"
}

variable "name" {
  type        = string
  description = "Prefix to be used on project parts where prefix is needed"
  default     = "tomorr"
}

variable "task_definition_image" {
  type        = string
  description = "ECR image for the task definition"
}

variable "bastion_host_security_group_id" {
  type        = string
  description = "Id of the bastion host security group"
}

variable "s3_env_bucket" {
  type        = string
  description = "Name of the S3 bucket that will hold environment variables"
}
