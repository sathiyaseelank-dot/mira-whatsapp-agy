FROM python:3.11-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 1. Install system utilities and packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    tar \
    gzip \
    file \
    jq \
    sqlite3 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"

# 4. Clone Hermes Agent first
WORKDIR /app
RUN git clone https://github.com/NousResearch/hermes-agent.git /app/hermes-agent

# 5. Install all Hermes requirements, web tools, and web server extras
RUN pip3 install --no-cache-dir \
    fastapi \
    uvicorn \
    python-multipart \
    psutil \
    requests \
    httpx \
    huggingface_hub \
    croniter \
    pydantic \
    openai \
    rich \
    ruamel.yaml \
    python-dotenv \
    fire \
    aiohttp \
    ddgs \
    duckduckgo-search \
    prompt_toolkit \
    packaging \
    Markdown \
    jinja2 \
    tomli-w

# 6. Install WhatsApp bridge dependencies and stamp hash
WORKDIR /app/hermes-agent/scripts/whatsapp-bridge
RUN npm install --production || true \
    && python3 -c "import hashlib, pathlib; p = pathlib.Path('package.json'); (pathlib.Path('node_modules') / '.hermes-pkg-hash').write_text(hashlib.sha256(p.read_bytes()).hexdigest()[:16])"

# 7. Copy application server and entrypoint
WORKDIR /app
COPY server.py /app/server.py
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose Render PORT (default 10000)
EXPOSE 10000

ENTRYPOINT ["/app/entrypoint.sh"]
