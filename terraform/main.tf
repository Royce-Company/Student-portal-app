module "networking" {
  source = "./modules/networking"

  project_name   = var.project_name
  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  aws_region     = var.aws_region

  tags = var.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  tags = var.common_tags
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_version    = var.eks_cluster_version
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_subnet_ids
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_worker_role_arn  = module.iam.eks_worker_role_arn

  desired_size   = var.eks_desired_size
  min_size       = var.eks_min_size
  max_size       = var.eks_max_size
  instance_types = var.eks_instance_types

  tags = var.common_tags

  depends_on = [
    module.networking,
    module.iam
  ]
}

module "rds" {
  source = "./modules/rds"

  project_name           = var.project_name
  environment            = var.environment
  db_subnet_group_name   = module.networking.db_subnet_group_name
  vpc_security_group_ids = [module.networking.rds_security_group_id]

  allocated_storage       = var.rds_allocated_storage
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  storage_encrypted       = var.rds_storage_encrypted

  database_name = var.rds_database_name
  username      = var.rds_master_username
  password      = var.rds_master_password

  tags = var.common_tags

  depends_on = [module.networking]
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  image_scan_on_push = true
  image_tag_mutability = "IMMUTABLE"

  tags = var.common_tags
}

# Additional configurations
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-logs"
    }
  )
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-terraform-state"
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name             = "terraform-state-lock"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "LockID"
  stream_view_type = "NEW_AND_OLD_IMAGES"
  stream_specification {
    stream_view_type = "NEW_AND_OLD_IMAGES"
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.common_tags
}

data "aws_caller_identity" "current" {}
