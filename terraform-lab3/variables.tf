variable "prefix" {
  type        = string
  description = "Префікс для найменування ресурсів (Формат: ім'я-прізвище-варіант)"
}

variable "vpc_cidr" {
  description = "CIDR блок для розгортання VPC"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "Помилка: Необхідно вказати валідний IPv4 CIDR блок (наприклад, 10.1.0.0/16)."
  }
}

variable "subnet_a_cidr" {
  type = string
}

variable "subnet_b_cidr" {
  type = string
}

variable "web_port" {
  description = "TCP Порт для доступу до вебсервера Apache"
  type        = number

  validation {
    condition     = var.web_port >= 1024 && var.web_port <= 65535
    error_message = "Помилка: Порт повинен знаходитись у безпечному непривілейованому діапазоні (1024-65535)."
  }
}

variable "apache_server_name" {
  type = string
}

variable "apache_doc_root" {
  type = string
}
