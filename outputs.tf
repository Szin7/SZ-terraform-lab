
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_2.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}

output "route_table_id" {
  value = aws_route_table.public.id
}

output "security_group_id" {
  value = aws_security_group.web.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.web.name
}

output "alb_dns_name" {
  value = aws_lb.web.dns_name
}

output "website_url" {
  value = "http://${aws_lb.web.dns_name}"
}
