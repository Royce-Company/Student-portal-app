variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "eks_cluster_version" {
  type = string
}

variable "eks_desired_size" {
  type = number
}

variable "eks_min_size" {
  type = number
}

variable "eks_max_size" {
  type = number
}

variable "eks_instance_types" {
  type = list(string)
}

variable "rds_allocated_storage" {
  type = number
}

variable "rds_engine_version" {
  type = string
}

variable "rds_instance_class" {
  type = string
}

variable "rds_multi_az" {
  type = bool
}

variable "rds_backup_retention_period" {
  type = number
}

variable "rds_database_name" {
  type = string
}

variable "rds_master_username" {
  type      = string
  sensitive = true
}

variable "rds_master_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type = string
}

variable "enable_cdn" {
  type = bool
}

variable "common_tags" {
  type = map(string)
}
