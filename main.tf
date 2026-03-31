terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "lion-rari"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    #use_lockfile = true
  }
}
     
   
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tiqs_jenkins_bucket" {
  bucket        = "tiqsclass6-armageddon-public"
  force_destroy = true

  tags = {
    Name = "T.I.Q.S. Jenkins Webhook Bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "tiqs_jenkins_bucket_block" {
  bucket = aws_s3_bucket.tiqs_jenkins_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.tiqs_jenkins_bucket.id

  depends_on = [aws_s3_bucket_public_access_block.tiqs_jenkins_bucket_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.tiqs_jenkins_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "S3 Object" {
  bucket       = aws_s3_bucket.tiqs_jenkins_bucket.id
  key          = "suge-waf.jpg"
  source       = "${path.module}/images/S3 Object.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/S3 Object.png")
}

resource "aws_s3_object" "Successful-Pipeline" {
  bucket       = aws_s3_bucket.tiqs_jenkins_bucket.id
  key          = "jenkins-pipeline.jpg"
  source       = "${path.module}/images/Successful-Pipeline.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/Successful-Pipeline.png")
}

resource "aws_s3_object" "terraform code" {
  bucket       = aws_s3_bucket.tiqs_jenkins_bucket.id
  key          = "jenkins-webhook.jpg"
  source       = "${path.module}/images/terraform code.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/terraform code.png")
}

resource "aws_s3_object" "VPC CREATION" {
  bucket       = aws_s3_bucket.tiqs_jenkins_bucket.id
  key          = "vpc-creation.png"
  source       = "${path.module}/images/VPC CREATION.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/VPC CREATION.png")
}

resource "aws_s3_object" "Webhook" {
  bucket       = aws_s3_bucket.tiqs_jenkins_bucket.id
  key          = "webhook.png"
  source       = "${path.module}/images/Webhook.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/Webhook.png")
}

resource "aws_s3_object" "Armageddon" {
  bucket       = aws_s3_bucket.tiqs_jenkins_bucket.id
  key          = "Armageddon.md"
  source       = "${path.module}/images/Armageddon.md"
  content_type = "text/markdown"

  etag = filemd5("${path.module}/images/Armageddon.md")
}
