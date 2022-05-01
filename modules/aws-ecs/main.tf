// Cluter
resource "aws_ecs_cluster" "application" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

// EC2 instance
resource "aws_security_group" "application" {
  name        = "${var.name}-instance"
  description = "Security group for ${var.name}, allowing traffic for HTTP only"
  vpc_id      = var.vpc_id
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "HTTP for application"
    from_port        = var.container_port
    to_port          = var.container_port
    protocol         = "tcp"
    security_groups  = null
    self             = null
    prefix_list_ids  = null
    },
    {
      cidr_blocks      = null
      ipv6_cidr_blocks = null
      description      = "SSH for application"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      security_groups  = [var.bastion_host_security_group_id]
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
    "Name" = "${var.name} Instance Security Group"
  }
}

resource "aws_iam_role" "application_instance_role" {
  name = "${var.name}-instance-role"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = {
        Sid    = "",
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    }
  )
}

resource "aws_iam_role_policy" "instance" {
  name = "${var.name}-instance-role-policy"
  role = aws_iam_role.application_instance_role.id

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = "arn:aws:logs:*:*:*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*",
            "s3-object-lambda:Get*",
            "s3-object-lambda:List*"
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.environment_var.bucket}",
            "arn:aws:s3:::${aws_s3_bucket.environment_var.bucket}/*"
          ]
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "instance_attach" {
  role       = aws_iam_role.application_instance_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.application_instance_role.id
}

resource "aws_launch_template" "application" {
  name                   = "${var.name}-launch-template"
  image_id               = var.application_ami
  instance_type          = "t3.micro"
  key_name               = var.private_key_name
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  network_interfaces {
    security_groups = [aws_security_group.application.id]
  }

  user_data = base64encode(<<EOT
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.application.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true >> /etc/ecs/ecs.config
    EOT
  )
}

resource "aws_autoscaling_group" "application" {
  name                = var.name
  vpc_zone_identifier = var.private_subnets
  desired_capacity    = 0
  min_size            = 0
  max_size            = 4

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
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-instance"
    propagate_at_launch = true
  }
}

// Capacity provider
resource "aws_ecs_capacity_provider" "application" {
  name = "${var.name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.application.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "application" {
  cluster_name       = aws_ecs_cluster.application.name
  capacity_providers = [aws_ecs_capacity_provider.application.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.application.name
  }
}

// Task definition
resource "aws_ecs_task_definition" "application" {
  family                = var.name
  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "${var.container_name}",
      "image": "${var.task_definition_image}",
      "memory": 256,
      "cpu": 1024,
      "essential": true,
      "portMappings": [{
        "containerPort": ${var.container_port},
        "hostPort": ${var.container_port}
      }],
      "environmentFiles": [{
        "value": "arn:aws:s3:::${aws_s3_bucket.environment_var.bucket}/${var.name}.env",
        "type": "s3"
      }],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${var.name}-container",
            "awslogs-region": "eu-central-1",
            "awslogs-create-group": "true",
            "awslogs-stream-prefix": "${var.name}"
        }
      }
    }
  ]
  TASK_DEFINITION
  network_mode          = "awsvpc"
  execution_role_arn    = aws_iam_role.application_task_execution_role.arn
}

// Service
resource "aws_iam_role" "application_task_execution_role" {
  name = "${var.name}-task-execution-role"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = {
        Sid    = "",
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    }
  )
}

resource "aws_iam_role_policy_attachment" "execution_role_attach" {
  role       = aws_iam_role.application_task_execution_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "application_task" {
  name = "${var.name}-task-execution-role-policy"
  role = aws_iam_role.application_task_execution_role.id

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = "arn:aws:logs:*:*:*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*",
            "s3-object-lambda:Get*",
            "s3-object-lambda:List*"
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.environment_var.bucket}",
            "arn:aws:s3:::${aws_s3_bucket.environment_var.bucket}/*"
          ]
        }
      ]
    }
  )
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.name}-ecs-service"
  description = "Security group for ${var.name}, allowing traffic for HTTP only"
  vpc_id      = var.vpc_id
  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Port for application"
    from_port        = var.container_port
    to_port          = var.container_port
    protocol         = "tcp"
    security_groups  = null
    self             = null
    prefix_list_ids  = null
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      description      = "HTTPS for application"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      security_groups  = null
      self             = null
      prefix_list_ids  = null
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      description      = "HTTP for application"
      from_port        = 80
      to_port          = 80
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
    "Name" = "${var.name} Security Group"
  }
}

resource "aws_ecs_service" "application" {
  name                    = "${var.name}-service"
  cluster                 = aws_ecs_cluster.application.id
  enable_ecs_managed_tags = true
  task_definition         = aws_ecs_task_definition.application.arn
  desired_count           = 2

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    container_name   = var.container_name
    container_port   = var.container_port
    target_group_arn = var.alb_target_group_arn
  }

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  capacity_provider_strategy {
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.application.name
  }

  health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 20
  deployment_maximum_percent         = 100
}


# Enviornment variables S3 bucket
resource "aws_s3_bucket" "environment_var" {
  bucket = var.s3_env_bucket
}

resource "aws_s3_bucket_acl" "environment_var" {
  bucket = aws_s3_bucket.environment_var.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "environment_var" {
  bucket = aws_s3_bucket.environment_var.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "environment_var" {
  policy_id = "${var.name}-environment-data-bucket-policy"

  statement {
    actions   = ["s3:Get*", "s3:List*"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.environment_var.arn}/*"]
    principals {
      identifiers = [aws_iam_role.application_instance_role.arn, aws_iam_role.application_task_execution_role.arn]
      type        = "AWS"
    }
  }
}

resource "aws_s3_bucket_policy" "environment_var" {
  bucket = aws_s3_bucket.environment_var.id
  policy = data.aws_iam_policy_document.environment_var.json
}
