FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 1. Install system utilities and build tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    tar \
    gzip \
    jq \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js 20 (required for WhatsApp Baileys bridge)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"

# 4. Install essential Python libraries and Hermes dependencies
RUN pip3 install --no-cache-dir \
    fastapi \
    uvicorn \
    requests \
    httpx \
    huggingface_hub \
    croniter \
    pydantic \
    openai \
    rich \
    ruamel.yaml \
    python-dotenv \
    fire

# 5. Clone and install Hermes Agent
WORKDIR /app
RUN git clone https://github.com/NousResearch/hermes-agent.git /app/hermes-agent \
    && cd /app/hermes-agent \
    && pip3 install --no-cache-dir -r requirements.txt || true

# 6. Install WhatsApp bridge dependencies
WORKDIR /app/hermes-agent/scripts/whatsapp-bridge
RUN npm install --production || true

# 7. Copy application server and entrypoint
WORKDIR /app
COPY server.py /app/server.py
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Render defaults to port 10000
EXPOSE 10000

CMD ["/app/entrypoint.sh"]
