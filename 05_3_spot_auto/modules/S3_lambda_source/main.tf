resource "aws_s3_bucket" "lambda_src" {
  bucket = var.bucket_name
  tags = {
    Name = "${var.project}-${var.env}-s3-lambda-source"
    Project = var.project
    Env     = var.env
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_src.id
  key    = var.object_key
  source = var.source_zip_path
  etag   = filemd5(var.source_zip_path)
}

resource "aws_s3_bucket" "data_src" {
  bucket = var.bucket_data_name
  tags = {
    Name = "${var.project}-${var.env}-s3-data-source"
    Project = var.project
    Env     = var.env
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_object" "data_csv" {
  bucket = aws_s3_bucket.data_src.id
  key    = var.data_object_key
  source = var.source_data_path
}