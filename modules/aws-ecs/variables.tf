variable "cluster_name" {
  type        = string
  description = "ECS Cluster name"
}

variable "launch_template_sg_name" {
  type        = string
  description = "Security group name for the ECS launch template"
}

variable "vpc_id" {
  type        = string
  description = "VPC where the ECS will be launched"
}

variable "launch_template_name" {
  type        = string
  description = "Launch template name for the EC2 instances"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets that the ASG will use"
}

variable "private_key_name" {
  type        = string
  description = "Private key to be used when connection to EC2 instances"
}

variable "asg_name" {
  type        = string
  description = "ASG name"
}

variable "application_ami" {
  type        = string
  description = "AMI to use when deploying the EC2 instances"
}

variable "instance_name" {
  type        = string
  description = "Instance name to use when deploying the instances"
}

variable "capacity_provider_name" {
  type        = string
  description = "Name of the capacity provider to be used by the cluster"
}

variable "service_name" {
  type        = string
  description = "Name of the ECS service"
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

variable "name_prefix" {
  type        = string
  description = "Prefix to be used on project parts where prefix is needed"
  default     = "tomorr"
}

variable "task_definition_image" {
  type        = string
  description = "ECR image for the task definition"
}

variable "task_definition_family" {
  type        = string
  description = "Name of the task definition family"
}

variable "env_location" {
  type        = string
  description = "Name of the bucket and the file where the environemnt variables are stored"
}
