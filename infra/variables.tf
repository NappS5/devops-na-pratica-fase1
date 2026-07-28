variable "app_image_name" {
  description = "Nome/tag da imagem Docker construída para a aplicação"
  type        = string
  default     = "devops-task-api:latest"
}

variable "container_name" {
  description = "Nome do container Docker da aplicação"
  type        = string
  default     = "devops-task-api"
}

variable "host_port" {
  description = "Porta no host (máquina local) mapeada para o container"
  type        = number
  default     = 3000
}

variable "container_port" {
  description = "Porta interna do container em que a aplicação escuta"
  type        = number
  default     = 3000
}
