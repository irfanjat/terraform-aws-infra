# Subnet group — tells RDS which subnets it can use
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS PostgreSQL instance
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "15.7"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  # No public access — only reachable from EC2 inside VPC
  publicly_accessible = false

  # Backups
  backup_retention_period = 0
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Free tier — skip multi-AZ
  multi_az = false

  # Safety — set to true in production
  skip_final_snapshot       = true
  deletion_protection       = false

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
