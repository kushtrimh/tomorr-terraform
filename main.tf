terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.9.0"
    }
  }
  cloud {
    organization = "kushtrimh"

    workspaces {
      name = "tomorr"
    }
  }
}

locals {
  s3_env_bucket_name = "tomorr-environment-application"
}

provider "aws" {}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name               = "${var.name_prefix}-vpc"
  cidr               = "10.0.0.0/16"
  azs                = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  tags = {
    environment = var.environment
  }
}

# Bastion host
module "bastion_host" {
  source = "./modules/aws-bastion-host"

  name_prefix      = var.name_prefix
  private_key_name = var.private_key_name
  vpc_id           = module.vpc.vpc_id
  public_subnets   = module.vpc.public_subnets
  bastion_ami      = var.bastion_ami
}

# Database
module "database" {
  source = "./modules/aws-rds"

  name_prefix          = var.name_prefix
  name                 = var.rds_name
  username             = var.rds_username
  password             = var.rds_password
  parameter_group_name = var.rds_parameter_group_name
  vpc_id               = module.vpc.vpc_id
  port                 = var.rds_port
  ingress_cidr_blocks  = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
  private_subnets      = module.vpc.private_subnets
}

# Cache
module "redis_cache" {
  source = "./modules/aws-elasticache"

  name_prefix          = var.name_prefix
  vpc_id               = module.vpc.vpc_id
  parameter_group_name = var.cache_parameter_group_name
  port                 = var.cache_port
  private_subnets      = module.vpc.private_subnets
  ingress_cidr_blocks  = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
}

# Message queue
module "rabbit_mq" {
  source = "./modules/aws-rabbitmq"

  name_prefix         = var.name_prefix
  vpc_id              = module.vpc.vpc_id
  port                = var.mq_port
  username            = var.mq_username
  password            = var.mq_password
  private_subnets     = module.vpc.private_subnets
  ingress_cidr_blocks = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
}

# Load balancer
module "loadbalancer" {
  source = "./modules/aws-load-balancer"

  name_prefix    = var.name_prefix
  vpc_id         = module.vpc.vpc_id
  instance_port  = var.instance_port
  public_subnets = module.vpc.public_subnets
  environment    = var.environment
}

# ECR
module "ecr" {
  source = "./modules/aws-ecr"
  name   = var.ecr_name
}

# Enviornment variables S3 bucket
resource "aws_s3_bucket" "environment_var" {
  bucket = local.s3_env_bucket_name
}

resource "aws_s3_bucket_acl" "environment_var" {
  bucket = aws_s3_bucket.environment_var.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "loadbalancer" {
  bucket = aws_s3_bucket.environment_var.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ECS
module "application_ecs" {
  source = "./modules/aws-ecs"

  cluster_name = "${var.name_prefix}-cluster"

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  private_key_name = var.private_key_name

  launch_template_sg_name = "${var.name_prefix}-application"
  launch_template_name    = "${var.name_prefix}-application"
  asg_name                = "${var.name_prefix}-application"
  instance_name           = "${var.name_prefix}-application"
  capacity_provider_name  = "${var.name_prefix}-application"
  service_name            = "${var.name_prefix}-application"

  application_ami      = var.application_ami
  alb_target_group_arn = module.loadbalancer.alb_target_group_arn

  container_name = var.name_prefix
  container_port = var.instance_port

  task_definition_image  = "${module.ecr.arn}/tomorr"
  task_definition_family = "${var.name_prefix}-application"
  env_location           = "${aws_s3_bucket.environment_var.bucket}/${var.name_prefix}"
}
