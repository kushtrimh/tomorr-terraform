output "alb_target_group_arn" {
  value = aws_lb_target_group.application.arn
}

output "security_group_id" {
  value = aws_security_group.loadbalancer.id
}
