resource "aws_ssm_parameter" "ssh_private_key" {
  name        = "/${var.project}/${var.env}/ssh_private_key"
  type        = "SecureString"
  value       = var.ssh_private_key
  description = "Private SSH key for connecting to EC2"
}

resource "aws_ssm_parameter" "mysql_root_password" {
  name        = "/${var.project}/${var.env}/mysql_root_password"
  type        = "SecureString"
  value       = var.mysql_root_password
  description = "MySQL root password for EC2"
}