# Production environment configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "student-portal-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      Project     = "student-portal"
      ManagedBy   = "Terraform"
    }
  }
}

# Import main configuration from parent directory
module "root" {
  source = "../../."
  
  aws_region              = var.aws_region
  environment            = "production"
  project_name           = "student-portal"
  vpc_cidr               = var.vpc_cidr
  public_subnets        = var.public_subnets
  private_subnets       = var.private_subnets
  eks_cluster_version   = var.eks_cluster_version
  eks_desired_size      = var.eks_desired_size
  eks_min_size          = var.eks_min_size
  eks_max_size          = var.eks_max_size
  eks_instance_types    = var.eks_instance_types
  rds_allocated_storage = var.rds_allocated_storage
  rds_engine_version   = var.rds_engine_version
  rds_instance_class   = var.rds_instance_class
  rds_multi_az         = var.rds_multi_az
  rds_backup_retention_period = var.rds_backup_retention_period
  rds_database_name    = var.rds_database_name
  rds_master_username  = var.rds_master_username
  rds_master_password  = var.rds_master_password
  domain_name          = var.domain_name
  enable_cdn           = var.enable_cdn
  common_tags          = var.common_tags
}

output "eks_cluster_id" {
  value = module.root.eks_cluster_id
}

output "eks_cluster_endpoint" {
  value = module.root.eks_cluster_endpoint
}

output "configure_kubectl" {
  value = module.root.configure_kubectl
}
