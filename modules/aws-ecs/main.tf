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
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*",
            "s3-object-lambda:Get*",
            "s3-object-lambda:List*"
          ]
          Resource = "arn:aws:s3:::${var.env_location}/*"
        }
      ]
    }
  )
}

resource "aws_ecs_cluster" "application" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "application" {
  name        = var.name
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

resource "aws_launch_template" "application" {
  name          = "${var.name}-launch-template"
  image_id      = var.application_ami
  instance_type = "t3.micro"
  key_name      = var.private_key_name

  network_interfaces {
    security_groups = [aws_security_group.application.id]
  }
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

resource "aws_ecs_task_definition" "application" {
  family                = var.name
  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "${var.container_name}",
      "image": "${var.task_definition_image}",
      "memory": 512,
      "cpu": 1024,
      "essential": true,
      "portMappings": [{
        "containerPort": ${var.container_port},
        "hostPort": ${var.container_port}
      }],
      "environmentFiles": [{
        "value": "arn:aws:s3:::${var.env_location}",
        "type": "s3"
      }]
    }
  ]
  TASK_DEFINITION
  network_mode          = "awsvpc"
  execution_role_arn    = aws_iam_role.application_task_execution_role.arn
}

resource "aws_ecs_service" "application" {
  name                    = "${var.name}-service"
  cluster                 = aws_ecs_cluster.application.id
  enable_ecs_managed_tags = true
  task_definition         = aws_ecs_task_definition.application.arn
  desired_count           = 3

  network_configuration {
    subnets = var.private_subnets
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
}
