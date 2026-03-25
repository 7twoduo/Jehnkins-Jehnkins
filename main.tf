provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "shadows" {
  cidr_block       = "10.0.90.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "2-shadows"
  }
}
