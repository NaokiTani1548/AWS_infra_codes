variable "project" {}
variable "env" {}
variable "s3_bucket" {}
variable "s3_key" {}
variable "public1ID" {}
variable "VPCID" {}
variable "network_map" {
  type = map(object({
    vpc_id    = string
    subnet_id = string
  }))
}
variable "sg_map" {
  type = map(string)
}
variable "key_map" {
  type = map(string)
}