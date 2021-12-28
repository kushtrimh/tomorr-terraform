output "db_url" {
  value = aws_db_instance.db.address
}

output "db_name" {
  value = aws_db_instance.db.name
}

output "db_username" {
  value = aws_db_instance.db.username
}

output "db_port" {
  value = aws_db_instance.db.port
}

output "cache_nodes" {
  value = aws_elasticache_cluster.cache.cache_nodes
}

output "mq_instances" {
  value = aws_mq_broker.mq.instances
}
