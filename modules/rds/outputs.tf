output "db_endpoint" {
  description = "RDS endpoint — use this to connect from EC2"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}
