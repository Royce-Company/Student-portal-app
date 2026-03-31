output "db_instance_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_instance_name" {
  value = aws_db_instance.main.db_name
}

output "db_instance_address" {
  value = aws_db_instance.main.address
}

output "db_instance_port" {
  value = aws_db_instance.main.port
}

output "db_instance_resource_id" {
  value = aws_db_instance.main.resource_id
}

output "rds_credentials_secret_arn" {
  value = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_credentials_secret_name" {
  value = aws_secretsmanager_secret.rds_credentials.name
}
