resource "aws_security_group" "bastion_host" {
  name        = "${var.name_prefix}-bastion-host"
  description = "Security group for bastion hosts, allowing traffic for SSH only"
  vpc_id      = var.vpc_id
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
  vpc_zone_identifier = var.public_subnets
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1

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

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-bastion-host"
    propagate_at_launch = true
  }
}
