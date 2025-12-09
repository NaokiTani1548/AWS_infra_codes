# ---------------------------------------------
# key pair
# ---------------------------------------------
resource "aws_key_pair" "keypair" {
  key_name   = "${var.project}-${var.env}-keypair"
  public_key = file("../../key/spot-db-test.pub")
  tags = {
    Name    = "${var.project}-${var.env}-keypair"
    Project = var.project
    Env     = var.env
  }
}

# ---------------------------------------------
# security group
# ---------------------------------------------
resource "aws_security_group" "db_sg" {
  name        = "${var.project}-${var.env}-db-sg"
  description = "Security group for DB server"
  vpc_id      = var.VPCID

  # SSHポートのインバウンドルール
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # または特定のIPアドレス範囲
  }
  # DBポートのインバウンドルール
  ingress {
    from_port   = 3306  # MySQLの場合
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC内からのアクセスのみ
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------
# Lambda Function
# ---------------------------------------------
resource "aws_lambda_function" "boot_spot" {
  function_name = "${var.project}-${var.env}-boot-spot"
  role          = aws_iam_role.lambda_role.arn
  s3_bucket = var.s3_bucket
  s3_key    = var.s3_key
  handler       = "boot_spot.lambda_handler"
  runtime       = "python3.9"
  timeout       = 120
  layers = [ "arn:aws:lambda:ap-northeast-1:058898200941:layer:paramiko-layer:5" ]

  environment {
    variables = {
        KYENAME = aws_key_pair.keypair.key_name
        SUBNETID = var.public1ID
        SECURITYGROUPEIDS = aws_security_group.db_sg.id
    }
  }

  tags = {
    Name = "${var.project}-${var.env}-lambda"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-${var.env}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project}-${var.env}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DetachVolume",
          "ec2:AttachVolume",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeImages",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
       {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}