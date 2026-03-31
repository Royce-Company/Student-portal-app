variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "student-portal"
}

variable "tags" {
  type    = map(string)
  default = {}
}
