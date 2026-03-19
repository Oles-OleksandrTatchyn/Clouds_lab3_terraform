output "ec2_public_ip" {
  description = "Публічна IPv4 адреса розгорнутого вебсервера"
  value       = aws_instance.web_server.public_ip
}

output "website_url" {
  description = "Пряме URL-посилання для доступу до вебсайту"
  value       = "http://${aws_instance.web_server.public_ip}:${var.web_port}"
}
