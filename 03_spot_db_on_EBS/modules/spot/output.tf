output "spot_db_volume_id" {
  value = aws_ebs_volume.spot-db-volume.id
}
output "spot_db_destination_instance_id" {
  value = aws_spot_instance_request.spot-db-test-destination.spot_instance_id
}