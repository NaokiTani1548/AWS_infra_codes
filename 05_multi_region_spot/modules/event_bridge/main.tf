resource "aws_cloudwatch_event_bus" "central" {
  name = "central-spot-events"
}

resource "aws_cloudwatch_event_rule" "central_rule" {
  name          = "spot-interruption-central"
  event_bus_name = aws_cloudwatch_event_bus.central.name

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "central_lambda" {
  rule          = aws_cloudwatch_event_rule.central_rule.name
  event_bus_name = aws_cloudwatch_event_bus.central.name
  arn           = aws_lambda_function.boot_spot.arn
}

resource "aws_lambda_permission" "allow_eventbridge_central" {
  statement_id  = "AllowCentralEventBus"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.boot_spot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.central_rule.arn
}


resource "aws_cloudwatch_event_rule" "daily_boot_spot" {
  name        = "${var.project}-${var.env}-daily-boot-spot"
  description = "Run boot_spot every day at 9:00 JST"

  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "daily_boot_spot_target" {
  rule      = aws_cloudwatch_event_rule.daily_boot_spot.name
  target_id = "DailyBootSpotLambda"
  arn       = aws_lambda_function.boot_spot.arn
}

resource "aws_lambda_permission" "allow_eventbridge_daily" {
  statement_id  = "AllowExecutionFromEventBridgeDaily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.boot_spot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_boot_spot.arn
}

resource "aws_cloudwatch_event_bus_policy" "allow_put_from_regions" {
  event_bus_name = aws_cloudwatch_event_bus.central.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPutEventsFromSameAccount"
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "events:PutEvents"
      Resource  = aws_cloudwatch_event_bus.central.arn
    }]
  })
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
          "logs:DescribeLogStreams",
          "ssm:GetParameter",
          "s3:GetObject",
          "iam:PassRole",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "cloudwatch:PutMetricData"
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

resource "aws_iam_role" "eventbridge_putevents_local" {
  name = "${var.env}-${var.project}-eventbridge-putevents-central"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "putevents_policy" {
  role = aws_iam_role.eventbridge_putevents_local.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = aws_cloudwatch_event_bus.central.arn
    }]
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

# --------------------------------
# SNS Topic
# --------------------------------

resource "aws_sns_topic" "topic" {
  name       = "${var.project}-${var.env}-spot-interruption-topic"
  fifo_topic = false
}

resource "aws_sns_topic_subscription" "topic_subscription" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "email"
  endpoint  = "cguh1095@mail4.doshisha.ac.jp"
  confirmation_timeout_in_minutes = 5
}

resource "aws_sns_topic_policy" "policy" {
  arn    = aws_sns_topic.topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

# EventBridgeからSNSへのアクセス許可
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.topic.arn]
  }
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.daily_boot_spot.name
  arn  = aws_sns_topic.topic.arn
}