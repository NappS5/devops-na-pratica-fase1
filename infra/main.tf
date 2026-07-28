terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

locals {
  # Raiz do projeto (um nível acima de infra/), usada como contexto do build
  project_root = abspath("${path.module}/..")
}

# Constrói a imagem da aplicação via Docker CLI.
#
# O mecanismo de build interno do provider kreuzwerker/docker (resource
# docker_image com bloco build) falha no macOS com o erro:
#   "unpigz: skipping: <stdin>: corrupted — incomplete deflate data"
# Para contornar essa incompatibilidade, o build é delegado ao Docker CLI
# via provisioner local-exec, e o provider apenas consome a imagem já criada.
resource "terraform_data" "app_image_build" {
  triggers_replace = {
    dockerfile        = filesha256("${local.project_root}/Dockerfile")
    package_json      = filesha256("${local.project_root}/package.json")
    package_lock_json = filesha256("${local.project_root}/package-lock.json")
    app_js            = filesha256("${local.project_root}/src/app.js")
    server_js         = filesha256("${local.project_root}/src/server.js")
  }

  provisioner "local-exec" {
    command = "docker build -t ${var.app_image_name} ${local.project_root}"
  }
}

# Localiza, no daemon Docker local, a imagem construída pelo provisioner acima
data "docker_image" "app" {
  name = var.app_image_name

  depends_on = [terraform_data.app_image_build]
}

# Sobe um container local expondo a API na porta configurada
resource "docker_container" "app" {
  name  = var.container_name
  image = data.docker_image.app.id

  ports {
    internal = var.container_port
    external = var.host_port
  }

  env = [
    "PORT=${var.container_port}"
  ]

  depends_on = [data.docker_image.app]
}
