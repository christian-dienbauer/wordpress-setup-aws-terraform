output "vpc_id" {
  value = aws_vpc.wordpress-cd.id
}

output "load_balancer_dns" {
  value = aws_lb.wordpress-cd.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.wordpress-cd.endpoint
}
