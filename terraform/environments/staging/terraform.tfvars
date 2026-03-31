environment = "staging"
aws_region  = "us-east-2"

vpc_cidr        = "10.1.0.0/16"
public_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnets = ["10.1.10.0/24", "10.1.11.0/24"]

eks_cluster_version = "1.28"
eks_desired_size    = 2
eks_min_size        = 1
eks_max_size        = 5
eks_instance_types  = ["t3.small"]

rds_allocated_storage       = 50
rds_engine_version         = "8.0.35"
rds_instance_class         = "db.t3.micro"
rds_multi_az               = false
rds_backup_retention_period = 7
rds_storage_encrypted       = true
rds_database_name          = "student_app"
rds_master_username        = "admin"

# Use AWS Secrets Manager for password
# rds_master_password should be set via environment variable: TF_VAR_rds_master_password

domain_name = "staging.student-portal.giize.com"
enable_cdn  = false

common_tags = {
  Environment = "staging"
  Project     = "student-portal"
  ManagedBy   = "Terraform"
  Team        = "DevOps"
}
