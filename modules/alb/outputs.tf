output "alb_dns_name" {
  description = "DNS name of the ALB — use this to access your app"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "Target group ARN — used by Auto Scaling Group"
  value       = aws_lb_target_group.main.arn
}
