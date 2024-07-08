variable "region" {
  default = "eu-central-1"
}

variable "tag" {
  default = "christian-dienbauer.dev"
}

variable "image_id" {
  default     = "ami-0e872aee57663ae2d"
  description = "The id of the machine image (AMI) to use for the server."
}

variable "instance_type" {
  default = "t2.micro"
}
