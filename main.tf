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

  name            = "tomorr-dev-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    environment = var.environment
  }
}

module "nat_instance" {
  source  = "int128/nat-instance/aws"
  version = "2.0.0"

  name                        = "main"
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
    Name = "nat-instance-eni"
  }
}
