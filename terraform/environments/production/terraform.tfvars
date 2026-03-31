environment = "production"
aws_region  = "us-east-2"

vpc_cidr        = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

eks_cluster_version = "1.28"
eks_desired_size    = 3
eks_min_size        = 2
eks_max_size        = 10
eks_instance_types  = ["t3.medium"]

rds_allocated_storage       = 100
rds_engine_version         = "8.0.35"
rds_instance_class         = "db.t3.small"
rds_multi_az               = true
rds_backup_retention_period = 30
rds_storage_encrypted       = true
rds_database_name          = "student_app"
rds_master_username        = "admin"

# Use AWS Secrets Manager for password in production
# rds_master_password should be set via environment variable: TF_VAR_rds_master_password

domain_name = "student-portal.giize.com"
enable_cdn  = true

common_tags = {
  Environment = "production"
  Project     = "student-portal"
  ManagedBy   = "Terraform"
  Team        = "DevOps"
}
