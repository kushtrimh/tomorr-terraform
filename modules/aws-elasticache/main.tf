resource "aws_security_group" "cache" {
  name        = "${var.name_prefix}-cache"
  description = "Security group for ElastiCache instances"
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
    "Name" = "${var.name_prefix} Cache Security Group"
  }
}

resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.name_prefix}-subnet-group"
  subnet_ids = var.private_subnets

}

resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "${var.name_prefix}-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = var.parameter_group_name
  engine_version       = "6.x"
  subnet_group_name    = aws_elasticache_subnet_group.cache.name
  security_group_ids   = [aws_security_group.cache.id]
  port                 = var.port
}
