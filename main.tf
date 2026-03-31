terraform {
  backend "s3" {
    bucket       = "lion-rari"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    #use_lockfile = true
  }
}
     
   
resource "aws_vpc" "shadows" {
  cidr_block       = "10.2.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "2-shadows"
  }
}
