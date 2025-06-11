output "ebs_volume_id" {
  value = aws_ebs_volume.spot-db-volume.id
}
output "spot_db_instance_id" {
  value = aws_spot_instance_request.spot-db.spot_instance_id
}

output "ondemand_db_instance_id" {
  value = aws_instance.ondemand-db.id
}

output "spot_instance_host" {
  value = aws_spot_instance_request.spot-db.host_id
}

output "ondemand_instance_host" {
  value = aws_instance.ondemand-db.host_id
}