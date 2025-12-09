output "VPCID" {
  value = aws_vpc.vpc.id
}

output "public1ID" {
  value = aws_subnet.public_subnet_1.id
}

output "public2ID" {
  value = aws_subnet.public_subnet_2.id
}