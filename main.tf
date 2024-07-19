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

resource "aws_vpc" "wordpress_cd" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.tag
  }
}

resource "aws_subnet" "wordpress_cd_a" {
  vpc_id                  = aws_vpc.wordpress_cd.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = var.tag
  }
}

resource "aws_subnet" "wordpress_cd_b" {
  vpc_id                  = aws_vpc.wordpress_cd.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = var.tag
  }
}

resource "aws_subnet" "wordpress_cd_c" {
  vpc_id                  = aws_vpc.wordpress_cd.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = var.tag
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.wordpress_cd.id

  tags = {
    Name = var.tag
  }
}

resource "aws_route_table" "wordpress_cd" {
  vpc_id = aws_vpc.wordpress_cd.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.wordpress_cd_a.id
  route_table_id = aws_route_table.wordpress_cd.id
}

resource "aws_route_table_association" "public-b" {
  subnet_id      = aws_subnet.wordpress_cd_b.id
  route_table_id = aws_route_table.wordpress_cd.id
}

resource "aws_route_table_association" "public-c" {
  subnet_id      = aws_subnet.wordpress_cd_c.id
  route_table_id = aws_route_table.wordpress_cd.id
}

resource "aws_security_group" "allow_http" {
  vpc_id = aws_vpc.wordpress_cd.id

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
  vpc_id = aws_vpc.wordpress_cd.id

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

resource "aws_db_instance" "wordpress_cd" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = var.db_admin
  password               = var.db_admin_pw # Consider using AWS Secrets Manager instead
  db_subnet_group_name   = aws_db_subnet_group.wordpress_cd.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name = "wordpress-cd-rds"
  }
}

resource "aws_db_subnet_group" "wordpress_cd" {
  name       = "wordpress-cd-subnet-group"
  subnet_ids = [aws_subnet.wordpress_cd_a.id, aws_subnet.wordpress_cd_b.id, aws_subnet.wordpress_cd_c.id]

  tags = {
    Name = "wordpress-cd-subnet-group"
  }
}

# AWS Backup setup for RDS
resource "aws_backup_vault" "wordpress_cd_backup_vault" {
  name = "wordpress-cd-backup-vault"

  tags = {
    Name = var.tag
  }
}

resource "aws_backup_plan" "wordpress_cd_backup_plan" {
  name = "wordpress-cd-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.wordpress_cd_backup_vault.name
    schedule          = "cron(0 5 * * ? *)"
    lifecycle {
      delete_after = 30
    }
  }

  tags = {
    Name = "wordpress-cd-backup-plan"
  }
}

resource "aws_backup_selection" "rds_backup_selection" {
  plan_id      = aws_backup_plan.wordpress_cd_backup_plan.id
  name         = "wordpress-cd-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  resources    = [aws_db_instance.wordpress_cd.arn]

}

resource "aws_iam_role" "backup_role" {
  name = "backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "backup-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "rds:DescribeDBInstances",
            "rds:DescribeDBSnapshots",
            "rds:CreateDBSnapshot",
            "rds:DeleteDBSnapshot",
            "rds:ListTagsForResource"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}

# Setup Wordpress and create an AMI

resource "aws_security_group" "wordpress_setup" {
  vpc_id = aws_vpc.wordpress_cd.id

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

resource "aws_instance" "wordpress_setup" {
  ami                    = var.image_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.wordpress_cd_c.id
  vpc_security_group_ids = [aws_security_group.wordpress_setup.id]

  user_data = templatefile("wordpress_setup.tftpl",
    {
      rds_address       = aws_db_instance.wordpress_cd.address,
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
    command = "sleep 120"
  }

  depends_on = [aws_instance.wordpress_setup]
}

resource "aws_ami_from_instance" "wordpress_ami" {
  name               = "wordpress-cd"
  source_instance_id = aws_instance.wordpress_setup.id
  depends_on = [
    null_resource.wordpress_ami_delay
  ]
  lifecycle {
    ignore_changes = [source_instance_id]
  }
}


resource "null_resource" "terminate_wordpress_setup" {
  depends_on = [aws_ami_from_instance.wordpress_ami]

  provisioner "local-exec" {
    command = <<EOT
      aws ec2 terminate-instances --instance-ids ${aws_instance.wordpress_setup.id} --region ${var.region}
      aws ec2 wait instance-terminated --instance-ids ${aws_instance.wordpress_setup.id} --region ${var.region}
    EOT
  }
}

# Run Wordpress in an autoscaling group behind a load balancer

resource "aws_launch_template" "wordpress_cd" {
  name_prefix   = "wordpress-cd-"
  image_id      = aws_ami_from_instance.wordpress_ami.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.allow_http.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wordpress_cd" {
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.wordpress_cd_a.id, aws_subnet.wordpress_cd_b.id, aws_subnet.wordpress_cd_c.id]
  launch_template {
    id      = aws_launch_template.wordpress_cd.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "wordpress-cd"
    propagate_at_launch = true
  }
}

resource "aws_lb" "wordpress_cd" {
  name               = "wordpress-cd-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http.id]
  subnets            = [aws_subnet.wordpress_cd_a.id, aws_subnet.wordpress_cd_b.id, aws_subnet.wordpress_cd_c.id]

  tags = {
    Name = var.tag
  }
}

resource "aws_lb_target_group" "wordpress_cd" {
  name        = "wordpress-cd-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wordpress_cd.id
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
  load_balancer_arn = aws_lb.wordpress_cd.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:eu-central-1:058264264767:certificate/c5fc59b8-560c-46cf-9aa6-49ab3607f51f"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_cd.arn
  }
}


resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.wordpress_cd.name
  lb_target_group_arn    = aws_lb_target_group.wordpress_cd.arn
}
