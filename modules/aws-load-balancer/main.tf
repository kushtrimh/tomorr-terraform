resource "aws_security_group" "loadbalancer" {
  name        = "${var.name}-loadbalancer"
  description = "Security group for the load balancer"
  vpc_id      = var.vpc_id
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
    "Name" = "${var.name} Load Balancer Security Group"
  }
}

data "aws_elb_service_account" "loadbalancer" {}

data "aws_iam_policy_document" "s3_loadbalancer" {
  policy_id = "${var.name}-loadbalancer-access-logs-policy"

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
  bucket_prefix = "${var.name}-alb-access-logs"
  force_destroy = true

  tags = {
    Name        = "${var.name}-alb-access-logs"
    environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "loadbalancer" {
  bucket = aws_s3_bucket.loadbalancer.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "loadbalancer" {
  bucket = aws_s3_bucket.loadbalancer.id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "loadbalancer" {
  bucket = aws_s3_bucket.loadbalancer.id
  policy = data.aws_iam_policy_document.s3_loadbalancer.json
}

resource "aws_lb" "loadbalancer" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer.id]
  subnets            = var.public_subnets

  access_logs {
    bucket  = aws_s3_bucket.loadbalancer.bucket
    prefix  = "${var.name}-access-log"
    enabled = true
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_lb_target_group" "application" {
  name        = "${var.name}-application"
  port        = var.instance_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled = true
    port    = var.instance_port
  }
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
