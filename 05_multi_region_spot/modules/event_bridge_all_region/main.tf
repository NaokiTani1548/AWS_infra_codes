resource "aws_cloudwatch_event_rule" "spot_local" {
  name     = "spot-interruption-local"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "to_central_bus" {
  rule = aws_cloudwatch_event_rule.spot_local.name
  arn  = "arn:aws:events:ap-northeast-1:058898200941:event-bus/central-spot-events"
  role_arn = var.eventbridge_local_role
}