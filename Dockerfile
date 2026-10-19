FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends chromium fonts-noto-cjk python3 make g++ && rm -rf /var/lib/apt/lists/*
ENV CHROMIUM_PATH=/usr/bin/chromium NODE_ENV=production DATA_DIR=/data
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev
VOLUME /data
EXPOSE 4100
CMD ["node", "server/index.js"]
