
# --------------------------------
# Role for SSM
# --------------------------------
resource "aws_iam_role" "ssm_role" {
    name = "${var.project}-${var.env}-ssm-role"
    assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
    "Effect": "Allow",
    "Principal": {
        "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
    }
]
}
EOF
}

resource "aws_iam_instance_profile" "ssm_profile" {
    name = "${var.project}-${var.env}-ssm-profile"
    role = aws_iam_role.ssm_role.name
}

resource "aws_iam_policy_attachment" "ssm_policy_attachment" {
    name = "${var.project}-${var.env}-ssm-policy-attachment"
    roles = [aws_iam_role.ssm_role.name]
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --------------------------------
# Security Group
# --------------------------------

resource "aws_security_group" "spot_sg" {
    name = "${var.project}-${var.env}-spot-sg"
    description = "Security group for spot instances"
    vpc_id = var.VPCID

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
}

# --------------------------------
# Spot Instance
# --------------------------------

resource "aws_spot_instance_request" "tmp_spot" {
  ami                            = "ami-0c16ff0f860575572"
  associate_public_ip_address    = true
  instance_type                  = "t2.micro"
  iam_instance_profile           = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids         = [aws_security_group.spot_sg.id]
  subnet_id                      = var.public1ID
  spot_type                      = "one-time"
  instance_interruption_behavior = "terminate"
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project}-${var.env}-tmp-spot"
  }
}

resource "aws_ec2_tag" "tmp_spot_tag" {
  depends_on = [aws_spot_instance_request.tmp_spot]
  resource_id = aws_spot_instance_request.tmp_spot.spot_instance_id
  key         = "Name"
  value       = "SpotTest"
}

# --------------------------------
# CloudWatch Log
# --------------------------------

resource "aws_cloudwatch_log_group" "spot_log_group" {
  name              = "/fis/logs/"
  retention_in_days = 1
}

# --------------------------------
# FIS　Role
# --------------------------------

resource "aws_iam_role" "fis_role" {
    name = "${var.project}-${var.env}-fis-role"
    assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
    "Effect": "Allow",
    "Principal": {
        "Service": "fis.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
    }
]
}
EOF
}

# EC2　アクセス権限付与
resource "aws_iam_role_policy_attachment" "FIS-policy-attachment" {
  role       = aws_iam_role.fis_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorEC2Access"
}

# CloudWatch Logs　アクセス権限付与
resource "aws_iam_role_policy_attachment" "FIS-Logs-policy-attachment" {
  role       = aws_iam_role.fis_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}