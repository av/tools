![./assets/tools.png](./assets/tools.png)

Docker image for installing and running tools for LLM agents (MCP, OpenAPI, UVX, NPX, Python)

### Features

- Python / Node.js / Deno runtime, Rust toolchain - includes `python`, `node`, `uvx`, `npx`, `deno`, `cargo`
- Includes extra packages for managing MCP/OpenAPI tools and connections
  - [`mcpo`](https://github.com/open-webui/mcpo) - MCP to OpenAPI bridge
  - [`supergateway`](https://github.com/supercorp-ai/supergateway) - MCP STDIO/SSE bridge
  - [`@modelcontextprotocol/inspector`](https://github.com/modelcontextprotocol/inspector) - debugging tool for MCP
- Utils: `curl`, `jq`, `git`, `ffmpeg`
- Easy unified cache at `/app/cache` for all tools
- Scanned with `trivy` for vulnerabilities

### Usage

```bash
# Launch MCP tools in stdio mode
docker run ghcr.io/av/tools uvx mcp-server-time

# Bridge from MCP to OpenAPI
docker run -p 8000:8000 ghcr.io/av/tools uvx mcpo -- uvx mcp-server-time --local-timezone=America/New_York
# http://0.0.0.0:8000/docs -> see endpoint documentation

# Run MCP inspector
docker run -p 6274:6274 -p 6277:6277 ghcr.io/av/tools npx @modelcontextprotocol/inspector

# Persist the cache volume for quick restarts
# -v cache:/app/cache - named docker volume
# -v /path/to/my/cache:/app/cache - cache on the host
docker run -v cache:/app/cache ghcr.io/av/tools uvx mcp-server-time
```

In docker compose:

```yaml
services:
  time:
    image: ghcr.io/av/tools
    command: uvx mcp-server-time
    volumes:
      - cache:/app/cache

  fetch:
    image: ghcr.io/av/tools
    command: uvx mcpo -- uvx mcp-server-fetch
    ports:
      - 7133:8000
    volumes:
      - cache:/app/cache
```

---

Check out [Harbor](https://github.com/av/harbor) for a complete dockerized LLM environment.