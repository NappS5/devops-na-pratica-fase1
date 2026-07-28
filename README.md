# DevOps Task API

Projeto acadêmico individual da disciplina **DevOps na Prática** — **Fase 1: Configuração e Automação Inicial**.

## Descrição

A **DevOps Task API** é uma API REST simples para gerenciamento de tarefas (criação e listagem), construída em **Node.js** com **Express**. Os dados são armazenados **em memória** (sem banco de dados e sem serviços pagos), com o objetivo de manter o foco da Fase 1 nos fundamentos de configuração, automação, containerização, infraestrutura como código e integração contínua.

## Objetivos

- Construir uma aplicação simples, testável e bem estruturada.
- Separar a configuração da aplicação (`src/app.js`) da inicialização do servidor (`src/server.js`), permitindo testes automatizados sem subir uma porta real.
- Cobrir os principais fluxos com testes automatizados (Jest + Supertest).
- Containerizar a aplicação com um Dockerfile enxuto e seguro.
- Provisionar a infraestrutura local (container) via Terraform, usando o provider Docker.
- Automatizar testes e validação de infraestrutura por meio de um pipeline de CI no GitHub Actions.

## Tecnologias

- **Node.js** (>= 18)
- **Express** — framework HTTP
- **Jest** — framework de testes
- **Supertest** — testes de integração HTTP
- **Docker** — containerização
- **Terraform** (>= 1.5) + provider **kreuzwerker/docker**
- **GitHub Actions** — pipeline de CI

## Estrutura do projeto

```
DevOps/
├── src/
│   ├── app.js               # Configuração da aplicação Express (rotas, middlewares)
│   └── server.js             # Inicialização do servidor HTTP (lê PORT do ambiente)
├── tests/
│   └── app.test.js           # Testes automatizados (Jest + Supertest)
├── infra/
│   ├── main.tf                # Recursos Terraform (build via Docker CLI + container Docker)
│   ├── variables.tf           # Variáveis de entrada do Terraform
│   └── outputs.tf             # Outputs (URL local da API, id do container)
├── .github/
│   └── workflows/
│       └── ci.yml             # Pipeline de CI (testes + validação Terraform)
├── Dockerfile                 # Build da imagem da aplicação
├── .dockerignore
├── .gitignore
├── package.json
└── README.md
```

## Pré-requisitos

- [Node.js](https://nodejs.org/) 18 ou superior e npm
- [Docker](https://www.docker.com/) (opcional, para build/execução em container)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5 (opcional, para provisionar via IaC)

## Instalação

```bash
npm install
```

## Execução local

```bash
npm start
```

Por padrão a API sobe na porta `3000`. Para usar outra porta:

```bash
PORT=4000 npm start
```

### Endpoints disponíveis

| Método | Rota      | Descrição                                             |
|--------|-----------|--------------------------------------------------------|
| GET    | `/health` | Retorna `200` com o status do serviço                  |
| GET    | `/tasks`  | Retorna a lista de tarefas cadastradas                  |
| POST   | `/tasks`  | Cria uma tarefa (`title` obrigatório, `description` opcional) |

Exemplo de criação de tarefa:

```bash
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Estudar Terraform", "description": "Ler documentação do provider Docker"}'
```

Requisição sem `title` retorna `400`:

```bash
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"description": "Sem título"}'
```

## Testes

Os testes cobrem:

- `GET /health` retorna `200`;
- `GET /tasks` retorna um array;
- `POST /tasks` com título válido retorna sucesso (`201`);
- `POST /tasks` sem título retorna `400` com mensagem de erro.

Executar localmente:

```bash
npm test
```

Executar em modo CI (com relatório de cobertura, sem watch):

```bash
npm run test:ci
```

## Docker

### Build da imagem

```bash
docker build -t devops-task-api:local .
```

### Executar o container

```bash
docker run --rm -p 3000:3000 devops-task-api:local
```

A API estará disponível em `http://localhost:3000`.

Boas práticas aplicadas no `Dockerfile`:
- Imagem base `node:20-alpine` (enxuta);
- Instalação de apenas dependências de produção (`npm ci --omit=dev`);
- Cópia seletiva de arquivos (sem `node_modules`, testes, infra, etc. via `.dockerignore`);
- Execução do processo com usuário não-root (`node`).

## Terraform

A infraestrutura provisiona um container Docker local a partir da imagem da aplicação, expõe a porta `3000` e retorna a URL local da API como output.

### Estratégia de build da imagem

O provider `kreuzwerker/docker` oferece um mecanismo de build embutido (bloco `build` dentro do resource `docker_image`), mas esse mecanismo depende de `pigz`/`unpigz` para descompactar o contexto de build enviado ao daemon Docker. Em algumas instalações do Docker Desktop no macOS isso resulta na falha:

```
Error running legacy build: failed to read dockerfile:
unpigz: skipping: <stdin>: corrupted — incomplete deflate data
```

Para evitar essa incompatibilidade, a build da imagem **não** é feita pelo provider. Em vez disso:

1. Um resource `terraform_data` executa `docker build` diretamente via Docker CLI (provisioner `local-exec`), usando a raiz do projeto (um nível acima de `infra/`) como contexto de build. O build é reexecutado sempre que `Dockerfile`, `package.json`, `package-lock.json`, `src/app.js` ou `src/server.js` mudam (via `triggers_replace`).
2. O data source `docker_image` localiza, no daemon Docker local, a imagem `devops-task-api:latest` já construída pelo passo anterior.
3. O `docker_container` usa o `id` dessa imagem (`data.docker_image.app.id`) para subir o container.

Ou seja: o Terraform continua sendo a ferramenta de orquestração de toda a infraestrutura local, mas delega o build da imagem ao Docker CLI (o mesmo comando validado manualmente com `docker build -t devops-task-api .`) e depois provisiona o container através do provider Docker. Essa abordagem não depende de nuvem, registry remoto ou credenciais — tudo roda localmente.

### Comandos

```bash
cd infra

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Após o `apply`, o output `api_url` mostrará o endereço local da API (por padrão, `http://localhost:3000`).

### Remover a infraestrutura

```bash
cd infra
terraform destroy
```

> Requer o Docker em execução na máquina local, pois o provider `kreuzwerker/docker` se conecta ao daemon Docker local.

## Explicação do pipeline de CI

O workflow `.github/workflows/ci.yml` é executado em `push` e `pull_request` para a branch `main`, com dois jobs independentes:

1. **`test` — Testes da aplicação**
   - Faz checkout do código;
   - Configura o Node.js 20;
   - Executa `npm ci` (instalação determinística das dependências);
   - Executa `npm test` (suíte Jest/Supertest).

2. **`terraform` — Validação do Terraform**
   - Faz checkout do código;
   - Configura o Terraform;
   - Executa `terraform fmt -check -recursive` (garante formatação padronizada);
   - Executa `terraform init -backend=false` (inicializa sem exigir backend remoto/credenciais);
   - Executa `terraform validate` (valida sintaxe e consistência da configuração).

Nenhum credencial, token ou segredo é utilizado no pipeline — o job de Terraform apenas valida a configuração estaticamente, sem realizar `apply` em nuvem.

## Comandos necessários (resumo rápido)

```bash
# Instalação e testes
npm install
npm test
npm run test:ci

# Execução local
npm start

# Docker
docker build -t devops-task-api:local .
docker run --rm -p 3000:3000 devops-task-api:local

# Terraform
cd infra
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

## Resultados esperados

- Todos os testes automatizados (`npm test`) devem passar (4 testes: health, listagem, criação válida, criação inválida).
- `GET /health` deve responder `200` com um JSON indicando que o serviço está ativo.
- `POST /tasks` sem `title` deve responder `400` com uma mensagem de erro clara.
- A imagem Docker deve construir com sucesso e o container deve expor a API na porta `3000`.
- `terraform apply` deve criar o container da aplicação e exibir a URL local da API; `terraform destroy` deve removê-lo completamente.
- O pipeline de CI deve executar com sucesso em cada `push`/`pull request` para `main`, validando tanto o código da aplicação quanto a infraestrutura.

## Evidências

> Espaço reservado para inserir prints/registros da execução do projeto (a preencher pelo autor).

- [ ] Print da execução de `npm test` com todos os testes passando.
- [ ] Print do `curl`/Postman testando `GET /health`, `GET /tasks` e `POST /tasks`.
- [ ] Print do build e execução do container Docker (`docker build` / `docker run`).
- [ ] Print do `terraform apply` com o output `api_url` e do `terraform destroy`.
- [ ] Print do pipeline de CI executado com sucesso no GitHub Actions.
