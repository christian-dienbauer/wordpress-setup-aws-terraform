output "vpc_id" {
  value = aws_vpc.wordpress_cd.id
}

output "load_balancer_dns" {
  value = aws_lb.wordpress_cd.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.wordpress_cd.endpoint
}
