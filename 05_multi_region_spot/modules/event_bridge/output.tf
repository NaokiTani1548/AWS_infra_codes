output "eventbridge_local_role" {
  value = aws_iam_role.eventbridge_putevents_local.arn
}