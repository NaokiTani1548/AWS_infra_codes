# ---------------------------------------------
# key pair
# ---------------------------------------------
resource "aws_key_pair" "keypair" {
  key_name   = "${var.project}-${var.env}-keypair"
  public_key = file("./src/spotinstance-test-keypair.pub")
  tags = {
    Name    = "${var.project}-${var.env}-keypair"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_spot_instance_request" "spot-ec2-test" {
    #spot instance request
    wait_for_fulfillment            = "true"
    spot_type                       = "persistent"
    instance_interruption_behaviour = "stop"

    tags = {
        Name = "${var.project}-${var.env}-spot-ec2-test"
        Project = var.project
        Env = var.env
        Type = "spot"
    }

    lifecycle {
        ignore_changes = [ "id" ]
    }

    ami                         = data.aws_ami.app.id
    availability_zone           = "ap-northeast-1c"
    ebs_optimized               = false
    instance_type               = "t2.micro"
    key_name                    = aws_key_pair.keypair.key_name
    subnet_id = aws_subnet.public_subnet_1c.id
    vpc_security_group_ids = [
        aws_security_group.app_sg.id,
        aws_security_group.opmng_sg.id
    ]
}