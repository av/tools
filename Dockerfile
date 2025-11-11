FROM ghcr.io/astral-sh/uv:debian
RUN apt-get update && apt-get install -y curl jq gnupg git

# From https://github.com/vercel/install-node/
RUN curl -sfLS https://install-node.vercel.app/lts | FORCE=true bash

WORKDIR /app
ENV UV_CACHE_DIR=/app/cache/uv
ENV npm_config_cache=/app/cache/npm
ENV npm_config_update_notifier=false

RUN npm i -g deno
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal && \
    echo 'source ~/.cargo/env' >> ~/.bashrc
ENV PATH="/root/.cargo/bin:${PATH}"

RUN uvx mcpo --help \
    && npx -y supergateway --help \
    && npx -y @modelcontextprotocol/inspector | { grep -m 1 "running" && pkill -f "@modelcontextprotocol/inspector"; } \
    && npx -y @metamcp/mcp-server-metamcp@latest --help