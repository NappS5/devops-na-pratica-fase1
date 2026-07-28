# Imagem enxuta, baseada em Node LTS Alpine
FROM node:24-alpine

WORKDIR /usr/src/app

# Instala apenas dependências de produção antes de copiar o código,
# aproveitando o cache de camadas do Docker
COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Executa como usuário não-root (imagem oficial já provê o usuário "node")
USER node

CMD ["node", "src/server.js"]
