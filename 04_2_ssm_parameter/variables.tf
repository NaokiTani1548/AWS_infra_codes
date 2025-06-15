variable "ssh_private_key" {
  description = "SSH private key in PEM format"
  type        = string
  sensitive   = true
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}