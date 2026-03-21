variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for EC2 instances"
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "Security group ID for EC2"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum ASG size"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum ASG size"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired ASG capacity"
  type        = number
}
