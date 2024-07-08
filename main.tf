terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.57.0"
    }
  }
}

provider "aws" {
  region = var.region
}


resource "aws_vpc" "wordpress-cd" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = var.tag
  }
}

resource "aws_subnet" "wordpress-cd-a" {
  vpc_id                  = aws_vpc.wordpress-cd.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = var.tag
  }
}

resource "aws_subnet" "wordpress-cd-b" {
  vpc_id                  = aws_vpc.wordpress-cd.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = var.tag
  }
}

resource "aws_subnet" "wordpress-cd-c" {
  vpc_id                  = aws_vpc.wordpress-cd.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = var.tag
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.wordpress-cd.id

  tags = {
    Name = var.tag
  }
}

resource "aws_route_table" "wordpress-cd" {
  vpc_id = aws_vpc.wordpress-cd.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.wordpress-cd-a.id
  route_table_id = aws_route_table.wordpress-cd.id
}

resource "aws_route_table_association" "public-b" {
  subnet_id      = aws_subnet.wordpress-cd-b.id
  route_table_id = aws_route_table.wordpress-cd.id
}

resource "aws_route_table_association" "public-c" {
  subnet_id      = aws_subnet.wordpress-cd-c.id
  route_table_id = aws_route_table.wordpress-cd.id
}

resource "aws_security_group" "allow_http" {
  vpc_id = aws_vpc.wordpress-cd.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
}

# REMOVE - Development only. 
resource "awscc_ec2_key_pair" "cdpubkey" {
  key_name            = "cdpubkey"
  public_key_material = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEWmpFpShRS7aaowUeOsh6TxqEGAqyQpotBc339lm2Va christian.dienbauer@dreamcodefactory.com"
}

resource "aws_launch_template" "wordpress-cd" {
  name_prefix   = "wordpress-cd-"
  image_id      = var.image_id
  instance_type = var.instance_type
  key_name      = awscc_ec2_key_pair.cdpubkey.key_name

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt update -y
              apt install -y apache2
              systemctl start apache2
              systemctl enable apache2
              echo "<h1>Hello, World from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.allow_http.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wordpress-cd" {
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.wordpress-cd-a.id, aws_subnet.wordpress-cd-b.id, aws_subnet.wordpress-cd-c.id]
  launch_template {
    id      = aws_launch_template.wordpress-cd.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "wordpress-cd-instance"
    propagate_at_launch = true
  }
}

resource "aws_lb" "wordpress-cd" {
  name               = "wordpress-cd-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http.id]
  subnets            = [aws_subnet.wordpress-cd-a.id, aws_subnet.wordpress-cd-b.id, aws_subnet.wordpress-cd-c.id]

  enable_deletion_protection = false

  tags = {
    Name = var.tag
  }
}

resource "aws_lb_target_group" "wordpress-cd" {
  name        = "wordpress-cd-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wordpress-cd.id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_lb_listener" "wordpress-cd" {
  load_balancer_arn = aws_lb.wordpress-cd.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-cd.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.wordpress-cd.name
  lb_target_group_arn    = aws_lb_target_group.wordpress-cd.arn
}



