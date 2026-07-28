output "container_id" {
  description = "ID do container Docker criado para a aplicação"
  value       = docker_container.app.id
}

output "api_url" {
  description = "URL local para acessar a DevOps Task API"
  value       = "http://localhost:${var.host_port}"
}
