resource "aws_s3_bucket" "lambda_src" {
  bucket = var.bucket_name
  tags = {
    Name = "${var.project}-${var.env}-s3-lambda-source"
    Project = var.project
    Env     = var.env
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_src.id
  key    = var.object_key
  source = var.source_zip_path
  etag   = filemd5(var.source_zip_path)
}