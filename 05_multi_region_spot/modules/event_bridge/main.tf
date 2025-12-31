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
        KEYNAME_MAP = jsonencode(var.key_map)
        SUBNETID = var.public1ID
        NETWORK_MAP = jsonencode(var.network_map)
        SECURITY_GROUP_MAP = jsonencode(var.sg_map)
        S3_DATA_PATH = var.s3_data_path
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
          "ec2:CopyImage",
          "ec2:RegisterImage",
          "ec2:GetSpotPlacementScores",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ssm:GetParameter",
          "s3:GetObject",
          "iam:PassRole",
          "s3:PutObject",
          "s3:PutObjectAcl"
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