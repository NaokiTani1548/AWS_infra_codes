resource "aws_ssm_parameter" "ssh_private_key" {
  name        = "/${var.project}/${var.env}/ssh_private_key"
  type        = "SecureString"
  value       = var.ssh_private_key
  description = "Private SSH key for connecting to EC2"
}