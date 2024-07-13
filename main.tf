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

# Setup VPC and subnets

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
    from_port   = 443
    to_port     = 443
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

# Create an RDS instance

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.wordpress-cd.id

  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "rds-security-group"
  }
}

resource "aws_db_instance" "main" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = var.db_admin
  password               = var.db_admin_pw # Consider using AWS Secrets Manager instead
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name = "main-rds"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = [aws_subnet.wordpress-cd-a.id, aws_subnet.wordpress-cd-b.id, aws_subnet.wordpress-cd-c.id]

  tags = {
    Name = "main-subnet-group"
  }
}

# Create database and user for wordpress

resource "aws_security_group" "wordpress_setup" { # Remove me
  vpc_id = aws_vpc.wordpress-cd.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "rds-security-group"
  }
}

resource "aws_instance" "wordpress_setup" { # TODO: terminate after database setup
  ami                    = var.image_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.wordpress-cd-c.id
  key_name               = awscc_ec2_key_pair.cdpubkey.key_name # Remove me
  vpc_security_group_ids = [aws_security_group.wordpress_setup.id]

  user_data = templatefile("wordpress_setup.tftpl",
    {
      rds_address       = aws_db_instance.main.address,
      admin             = var.db_admin,
      admin_pw          = var.db_admin_pw,
      wordpress_db      = var.db_wordpress,
      wordpress_user    = var.db_wordpress_user,
      wordpress_user_pw = var.db_wordpress_user_pw
    }
  )


  tags = {
    Name = "WordPress-setup"
  }
}

resource "null_resource" "wordpress_ami_delay" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [aws_instance.wordpress_setup]
}

resource "aws_ami_from_instance" "wordpress_ami" {
  name               = "wordpress-cd"
  source_instance_id = aws_instance.wordpress_setup.id
  depends_on = [
    null_resource.wordpress_ami_delay
  ]
}

# Setup ec2 instance behind a load balancer

# # REMOVE - Development only. 
resource "awscc_ec2_key_pair" "cdpubkey" {
  key_name            = "christian.dienbauer@dreamcodefactory.com"
  key_type            = "ed25519"
  public_key_material = file("~/.ssh/id_ed25519.pub")
}

resource "aws_launch_template" "wordpress-cd" {
  name_prefix   = "wordpress-cd-"
  image_id      = aws_ami_from_instance.wordpress_ami.id
  instance_type = var.instance_type
  key_name      = awscc_ec2_key_pair.cdpubkey.key_name # Remove me

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
    value               = "wordpress-cd"
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

# Define a listener for HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.wordpress-cd.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:eu-central-1:058264264767:certificate/c5fc59b8-560c-46cf-9aa6-49ab3607f51f"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-cd.arn
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
