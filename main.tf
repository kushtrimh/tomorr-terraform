terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "${var.name_prefix}-vpc"
  cidr            = "10.0.0.0/16"
  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  tags = {
    environment = var.environment
  }
}

module "nat_instance" {
  source  = "int128/nat-instance/aws"
  version = "2.0.0"

  name                        = var.name_prefix
  key_name                    = var.private_key_name
  vpc_id                      = module.vpc.vpc_id
  public_subnet               = module.vpc.public_subnets[0]
  private_subnets_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  private_route_table_ids     = module.vpc.private_route_table_ids
  instance_types              = ["t3.nano", "t3a.nano"]
  use_spot_instance           = true
}

resource "aws_eip" "nat_eip" {
  network_interface = module.nat_instance.eni_id
  tags = {
    Name = "${var.name_prefix}-nat-instance-eip"
  }
}

resource "aws_security_group" "bastion_host" {
  name        = "${var.name_prefix}-bastion-host"
  description = "Security group to for bastion hosts, allowing traffic for SSH only"
  vpc_id      = module.vpc.vpc_id
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "SSH for bastion hosts"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = null
    self             = null
    prefix_list_ids  = null
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    description      = null
    security_groups  = null
    self             = null
    prefix_list_ids  = null
  }]
}

resource "aws_launch_template" "bastion_host" {
  name_prefix   = var.name_prefix
  image_id      = var.bastion_ami
  instance_type = "t3a.nano"
  key_name      = var.private_key_name
  network_interfaces {
    security_groups = [aws_security_group.bastion_host.id]
  }
}

resource "aws_autoscaling_group" "bastion_host" {
  name                = "${var.name_prefix}-bastion-autoscaling-group"
  vpc_zone_identifier = module.vpc.public_subnets
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  tags = [{
    key                 = "Name"
    value               = "${var.name_prefix}-bastion-host"
    propagate_at_launch = true
  }]
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.bastion_host.id
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }
  }
}

resource "aws_db_subnet_group" "tomorr" {
  name       = "${var.name_prefix}-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_security_group" "tomorr" {
  name = "${var.name_prefix}-rds"
  ingress {
    cidr = var.rds_cidr
  }
}
