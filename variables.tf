variable "region" {
  default = "eu-central-1"
}

variable "tag" {
  default = "christian-dienbauer.dev"
}

variable "image_id" {
  default     = "ami-0e872aee57663ae2d" # Change accordingly 
  description = "The id of the machine image (AMI) to use for the server."
}

variable "instance_type" {
  default = "t2.micro"
}

# Database
variable "db_admin" {
  default = "admin"
}

variable "db_admin_pw" {
  default = "password" # Change this
}

variable "db_wordpress" {
  default = "wordpress"
}

variable "db_wordpress_user" {
  default = "wordpress"
}

variable "db_wordpress_user_pw" {
  default = "password" # Change this
}

