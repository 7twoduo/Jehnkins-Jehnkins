terraform {
  backend "s3" {
    bucket       = "lion-rari"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    #use_lockfile = true
  }
}



resource "aws_vpc" "shadows" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "2-shadows"
  }
}
