
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIATQX6QJCIHWTEHQHT"
  secret_key = "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"
}

resource "aws_instance" "myec2" {
    ami = "ami-0557a15b87f6559cf"
    instance_type = "t2.micro"
}
