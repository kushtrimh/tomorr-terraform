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
resource "aws_security_group" "bastion_host" {
  name        = "${var.name_prefix}-bastion-host"
  description = "Security group for bastion hosts, allowing traffic for SSH only"
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

  tags = {
    "Name" = "${var.name_prefix} Bastion Host Security Group"
  }
}

resource "aws_launch_template" "bastion_host" {
  name          = "${var.name_prefix}-bastion-host"
  image_id      = var.bastion_ami
  instance_type = "t3a.nano"
  key_name      = var.private_key_name
  network_interfaces {
    security_groups = [aws_security_group.bastion_host.id]
  }
}

resource "aws_autoscaling_group" "bastion_host" {
  name                = "${var.name_prefix}-bastion-host-autoscaling-group"
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

# Database
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-rds"
  description = "Security group for RDS instances"
  vpc_id      = module.vpc.vpc_id
  ingress = [{
    from_port        = var.rds_port
    to_port          = var.rds_port
    cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
    protocol         = "tcp"
    ipv6_cidr_blocks = null
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  tags = {
    "Name" = "${var.name_prefix} RDS Security Group"
  }
}


resource "aws_db_subnet_group" "db" {
  name       = "${var.name_prefix}-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "db" {
  identifier                      = "${var.name_prefix}-db"
  instance_class                  = "db.t4g.micro"
  allocated_storage               = 5
  engine                          = "postgres"
  engine_version                  = "13.3"
  name                            = var.rds_name
  username                        = var.rds_username
  password                        = var.rds_password
  db_subnet_group_name            = aws_db_subnet_group.db.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  parameter_group_name            = var.rds_parameter_group_name
  enabled_cloudwatch_logs_exports = ["postgresql"]
  publicly_accessible             = false
  multi_az                        = false
  skip_final_snapshot             = true
  apply_immediately               = true
  backup_retention_period         = 7
}

# Cache
resource "aws_security_group" "cache" {
  name        = "${var.name_prefix}-cache"
  description = "Security group for ElastiCache instances"
  vpc_id      = module.vpc.vpc_id
  ingress = [{
    from_port        = var.cache_port
    to_port          = var.cache_port
    cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
    protocol         = "tcp"
    ipv6_cidr_blocks = null
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  tags = {
    "Name" = "${var.name_prefix} Cache Security Group"
  }
}

resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.name_prefix}-subnet-group"
  subnet_ids = module.vpc.private_subnets

}

resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "${var.name_prefix}-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = var.cache_parameter_group_name
  engine_version       = "6.x"
  subnet_group_name    = aws_elasticache_subnet_group.cache.name
  security_group_ids   = [aws_security_group.cache.id]
  port                 = var.cache_port
}

# Message queue
resource "aws_security_group" "mq" {
  name        = "${var.name_prefix}-mq"
  description = "Security group for AmazonMQ instances"
  vpc_id      = module.vpc.vpc_id
  ingress = [{
    from_port        = var.mq_port
    to_port          = var.mq_port
    cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
    protocol         = "tcp"
    ipv6_cidr_blocks = null
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
    },
    {
      from_port        = 443
      to_port          = 443
      cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
      protocol         = "tcp"
      ipv6_cidr_blocks = null
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    },
    {
      from_port        = 15671
      to_port          = 15671
      cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
      protocol         = "tcp"
      ipv6_cidr_blocks = null
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
  }]

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  tags = {
    "Name" = "${var.name_prefix} MQ Security Group"
  }
}

resource "aws_mq_broker" "mq" {
  broker_name        = "${var.name_prefix}-mq"
  engine_type        = "RabbitMQ"
  engine_version     = "3.8.23"
  host_instance_type = "mq.t3.micro"
  deployment_mode    = "SINGLE_INSTANCE"
  security_groups    = [aws_security_group.mq.id]
  subnet_ids         = [module.vpc.private_subnets[0]]

  user {
    username = var.mq_username
    password = var.mq_password
  }
}

# Load balancer
resource "aws_security_group" "loadbalancer" {
  name        = "${var.name_prefix}-loadbalancer"
  description = "Security group for the load balancer"
  vpc_id      = module.vpc.vpc_id
  ingress = [{
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "tcp"
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
    },
    {
      from_port        = 443
      to_port          = 443
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      protocol         = "tcp"
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
  }]

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  tags = {
    "Name" = "${var.name_prefix} Load Balancer Security Group"
  }
}

data "aws_elb_service_account" "loadbalancer" {}

data "aws_iam_policy_document" "s3_loadbalancer" {
  policy_id = "${var.name_prefix}-loadbalancer-access-logs-policy"

  statement {
    actions   = ["s3:PutObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.loadbalancer.arn}/*"]
    principals {
      identifiers = ["${data.aws_elb_service_account.loadbalancer.arn}"]
      type        = "AWS"
    }
  }
}

resource "aws_s3_bucket" "loadbalancer" {
  bucket_prefix = "${var.name_prefix}-alb-access-logs"
  acl           = "private"
  force_destroy = true
  versioning {
    enabled = true
  }
  tags = {
    Name        = "${var.name_prefix}-alb-access-logs"
    environment = var.environment
  }
}

resource "aws_s3_bucket_policy" "loadbalancer" {
  bucket = aws_s3_bucket.loadbalancer.id
  policy = data.aws_iam_policy_document.s3_loadbalancer.json
}

resource "aws_lb" "loadbalancer" {
  name               = "${var.name_prefix}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer.id]
  subnets            = module.vpc.public_subnets

  access_logs {
    bucket  = aws_s3_bucket.loadbalancer.bucket
    prefix  = "${var.name_prefix}-access-log"
    enabled = true
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_lb_target_group" "application" {
  name        = "${var.name_prefix}-application"
  port        = var.instance_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled = true
    port    = 80
  }
}

resource "aws_autoscaling_attachment" "asg_alb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.application.id
  alb_target_group_arn   = aws_lb_target_group.application.arn
}

resource "aws_lb_listener" "name" {
  port              = 80
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.loadbalancer.arn

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.application.arn
      }
    }
  }
}

# Application
resource "aws_security_group" "application" {
  name        = "${var.name_prefix}-application"
  description = "Security group for the application instances"
  vpc_id      = module.vpc.vpc_id
  ingress = [{
    from_port        = var.instance_port
    to_port          = var.instance_port
    cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
    protocol         = "tcp"
    ipv6_cidr_blocks = null
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
    },
    {
      from_port        = 80
      to_port          = 80
      cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
      protocol         = "tcp"
      ipv6_cidr_blocks = null
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    },
    {
      from_port        = 443
      to_port          = 443
      cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
      protocol         = "tcp"
      ipv6_cidr_blocks = null
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    },
    {
      from_port        = 22
      to_port          = 22
      cidr_blocks      = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
      protocol         = "tcp"
      ipv6_cidr_blocks = null
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
  }]

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = null
    prefix_list_ids  = null
    security_groups  = null
    self             = null
  }]

  tags = {
    "Name" = "${var.name_prefix} Application Security Group"
  }
}

resource "aws_iam_role" "application" {
  name = "${var.name_prefix}-application-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        }
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "application" {
  name        = "${var.name_prefix}-ec2-application-policy"
  description = "Policy for ${var.name_prefix} EC2 instances"

  policy = <<EOF
{
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*",
          "s3-object-lambda:Get*",
          "s3-object-lambda:List*"
        ],
        "Resource" : "*"
      }
    ]
  }
EOF
}

resource "aws_iam_role_policy_attachment" "application" {
  role       = aws_iam_role.application.name
  policy_arn = aws_iam_policy.application.arn
}

resource "aws_iam_instance_profile" "application" {
  name = "${var.name_prefix}-application-instance-profile"
  role = aws_iam_role.application.name
}

resource "aws_launch_template" "application" {
  name          = "${var.name_prefix}-application"
  image_id      = var.instance_ami
  instance_type = "t3a.nano"
  key_name      = var.private_key_name

  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.application.arn
  }

  network_interfaces {
    security_groups = [aws_security_group.application.id]
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.name_prefix}-application"
      environment = var.environment
    }
  }
}

resource "aws_placement_group" "application" {
  name     = "${var.name_prefix}-application"
  strategy = "spread"
}

resource "aws_autoscaling_group" "application" {
  name                      = "${var.name_prefix}-applicaition-autoscaling-group"
  min_size                  = 2
  max_size                  = 3
  desired_capacity          = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  vpc_zone_identifier       = module.vpc.private_subnets

  target_group_arns = [aws_lb_target_group.application.arn]
  placement_group   = aws_placement_group.application.id

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.application.id
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }
  }

  lifecycle {
    ignore_changes = [
      target_group_arns,
      load_balancers
    ]
  }
}
