resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-rds"
  description = "Security group for RDS instances"
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
  subnet_ids = var.private_subnets
}

resource "aws_db_instance" "db" {
  identifier                      = "${var.name_prefix}-db"
  instance_class                  = "db.t4g.micro"
  allocated_storage               = 5
  engine                          = "postgres"
  engine_version                  = "13.3"
  name                            = var.name
  username                        = var.username
  password                        = var.password
  db_subnet_group_name            = aws_db_subnet_group.db.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  parameter_group_name            = var.parameter_group_name
  enabled_cloudwatch_logs_exports = ["postgresql"]
  publicly_accessible             = false
  multi_az                        = false
  skip_final_snapshot             = true
  apply_immediately               = true
  backup_retention_period         = 7
}
