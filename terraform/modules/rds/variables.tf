variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "allocated_storage" {
  type = number
}

variable "engine_version" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "backup_retention_period" {
  type = number
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "database_name" {
  type = string
}

variable "username" {
  type      = string
  sensitive = true
}

variable "password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
