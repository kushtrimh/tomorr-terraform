resource "aws_security_group" "mq" {
  name        = "${var.name_prefix}-mq"
  description = "Security group for AmazonMQ instances"
  vpc_id      = var.vpc_id
  ingress = [{
    from_port        = var.port
    to_port          = var.port
    cidr_blocks      = var.ingress_cidr_blocks
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
      cidr_blocks      = var.ingress_cidr_blocks
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
      cidr_blocks      = var.ingress_cidr_blocks
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
  subnet_ids         = [var.private_subnets[0]]

  user {
    username = var.username
    password = var.password
  }
}
