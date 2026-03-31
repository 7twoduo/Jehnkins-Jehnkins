terraform {
  # Added the required Terraform CLI version
  required_version = "~> 1.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Updated to the latest major version (v6)
      version = "~> 6.38.0" 
    }
  }

  backend "s3" {
    bucket       = "lion-rari"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    # use_lockfile = true
  }
}

resource "aws_vpc" "shadows" {
  cidr_block = "10.2.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "2-shadows"
  }
}
     
   
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "shadow_bucket" {
  bucket        = "shadow-lucky-rari"
  force_destroy = true

  tags = {
    Name = "shadow_bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "shadow_bucket_block" {
  bucket = aws_s3_bucket.shadow_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.shadow_bucket.id

  depends_on = [aws_s3_bucket_public_access_block.shadow_bucket_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.shadow_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "s3_object" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "S3 Object.png"
  source       = "${path.module}/images/S3 Object.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/S3 Object.png")
}

resource "aws_s3_object" "Successful-Pipeline" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "jenkins-pipeline.jpg"
  source       = "${path.module}/images/Successful-Pipeline.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/Successful-Pipeline.png")
}

resource "aws_s3_object" "terraform_code" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "jenkins-webhook.jpg"
  source       = "${path.module}/images/terraform code.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/terraform code.png")
}

resource "aws_s3_object" "VPC_CREATION" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "vpc-creation.png"
  source       = "${path.module}/images/VPC CREATION.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/VPC CREATION.png")
}

resource "aws_s3_object" "Webhook" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "webhook.png"
  source       = "${path.module}/images/Webhook.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/Webhook.png")
}

resource "aws_s3_object" "Snyk" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "Snyk-Failed.png"
  source       = "${path.module}/images/Snyk-Failed.png"
  content_type = "image/png"

  etag = filemd5("${path.module}/images/Snyk-Failed.png")
}

resource "aws_s3_object" "Armageddon" {
  bucket       = aws_s3_bucket.shadow_bucket.id
  key          = "Armageddon.md"
  source       = "${path.module}/Armageddon.md"
  content_type = "text/markdown"

  etag = filemd5("${path.module}/Armageddon.md")
}
