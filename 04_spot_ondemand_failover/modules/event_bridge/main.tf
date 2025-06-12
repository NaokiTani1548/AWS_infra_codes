resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.project}-${var.env}-spot-interruption"
  description = "Catch spot interruption"
  event_pattern = jsonencode({
    "source": ["aws.ec2"],
    "detail-type": ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.ebs_failover.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_failover.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spot_interruption.arn
}


#--------------------------------
# lambda function
#--------------------------------
resource "aws_lambda_function" "ebs_failover" {
  function_name = "${var.project}-${var.env}-ebs-failover"
  role          = aws_iam_role.lambda_role.arn
  s3_bucket = var.s3_bucket
  s3_key    = var.s3_key
  handler       = "ebs_failover.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  layers = [ "arn:aws:lambda:ap-northeast-1:058898200941:layer:paramiko-layer:5" ]

  environment {
    variables = {
        ONDEMAND_INSTANCE_ID = var.ondemand_instance_id
        VOLUME_ID            = var.volume_id
        SOURCE_HOST          = var.source_host
        DESTINATION_HOST     = var.destination_host
    }
  }

  tags = {
    Name = "${var.project}-${var.env}-lambda-failover-manager"
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
          "ec2:DescribeInstances",
          "ec2:DetachVolume",
          "ec2:AttachVolume",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus"
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