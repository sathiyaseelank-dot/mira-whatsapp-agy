#!/bin/bash
set -e

echo "=================================================="
echo "🚀 Starting Mira WhatsApp + Antigravity (AGY)..."
echo "=================================================="

# 1. Workspace directory for agy tasks
mkdir -p /app/workspace

# 2. Configure Antigravity CLI (agy)
mkdir -p /root/.gemini/antigravity-cli
cat << 'EOF' > /root/.gemini/antigravity-cli/settings.json
{
  "modelProvider": "gemini",
  "trustedWorkspaces": [
    "/app",
    "/app/workspace"
  ]
}
EOF
echo "✓ Antigravity CLI configured with Gemini provider"

# 3. Setup Hermes environment and persona
mkdir -p /root/.hermes/cron
mkdir -p /root/.hermes/whatsapp/session

# Unpack WhatsApp credentials if passed in env
if [ -n "$WHATSAPP_SESSION_B64" ]; then
    echo "Unpacking WhatsApp session from secret..."
    echo "$WHATSAPP_SESSION_B64" | base64 -d | tar -xz -C /root/.hermes/whatsapp/session || true
    echo "✓ Restored WhatsApp credentials"
fi

# SOUL.md - Mira Tanglish Companion (Short, Human, Empathetic)
cat << 'EOF' > /root/.hermes/SOUL.md
You are Mira, a caring, chill, and emotionally smart companion chatting on WhatsApp.

### Rules & Style:
- **Short & Human Format:** Reply in just 1 or 2 sentences maximum. Keep it brief, natural, and quick—exactly like a real human texting on WhatsApp. Never write lengthy paragraphs or essays.
- **Emotional Companion:** Understand how the person is feeling (stressed, sad, happy, tired, lonely) and respond with genuine care, warmth, and empathy like a true companion.
- **Language:** Pure casual Tanglish (conversational Tamil in English letters mixed with English).
  - Examples: "Enna aachu bro, tension aagadha... naan irukken.", "Romba tired-ah irukkeengala? Konjam rest edunga thala.", "Vera level, semma happy-ah irukku!"
- **No Robot Vibes:** Never say "As an AI", never use formal greetings or bulleted walls of text, and never tag or ping users with "@". Just text directly and naturally.
EOF

# Hermes config.yaml
cat << 'EOF' > /root/.hermes/config.yaml
plugins:
  enabled:
    - orca-status
_config_version: 54
model:
  provider: custom
  default: openai/gpt-oss-120b
  base_url: https://api.groq.com/openai/v1
  key_env: GROQ_API_KEY

providers:
  groq:
    base_url: https://api.groq.com/openai/v1
    api_key_env: GROQ_API_KEY
    api_mode: chat_completions

agent:
  disabled_toolsets:
    - terminal
    - browser
    - computer_use
    - file
    - coding
    - debugging
    - code_execution
    - cronjob
    - project
    - delegation
    - kanban
    - tts
    - image_gen
    - video_gen
    - memory
    - skills
    - session_search
    - clarify
    - todo
    - connections

platform_toolsets:
  whatsapp:
    - web

platforms:
  whatsapp:
    enabled: true
    dm_policy: open
    group_policy: open
    require_mention: true
    reply_prefix: ""
    mention_patterns:
      - "(?i)mira"
      - "(?i)@mira"
EOF

# Hermes .env
cat << EOF > /root/.hermes/.env
GROQ_API_KEY=${GROQ_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}
HF_TOKEN=${HF_TOKEN}
WHATSAPP_ALLOW_ALL_USERS=true
GATEWAY_ALLOW_ALL_USERS=true
WHATSAPP_HOME_CHANNEL=${WHATSAPP_HOME_CHANNEL:-}
EOF

# Daily News Cron Job: 8:00 AM & 8:00 PM IST
cat << 'EOF' > /root/.hermes/cron/jobs.json
{
  "jobs": [
    {
      "id": "daily-global-news",
      "name": "daily-global-news",
      "prompt": "Search the web for today's top 5 most important and trending global news stories. Summarize each story with a punchy headline and 1-2 sentence brief in casual, easy-to-read Tanglish. Format with clean bullet points for WhatsApp.",
      "schedule": {
        "kind": "cron",
        "expr": "0 8,20 * * *",
        "display": "0 8,20 * * *"
      },
      "schedule_display": "0 8,20 * * *",
      "repeat": { "times": null, "completed": 0 },
      "enabled": true,
      "deliver": "whatsapp",
      "timezone": "Asia/Kolkata",
      "enabled_toolsets": ["web"]
    }
  ]
}
EOF

# 4. Start Hermes WhatsApp Gateway in background
echo "Starting Hermes Gateway..."
python3 -m hermes_cli.main gateway run &

# 5. Start HTTP Healthcheck and AGY API server on Render PORT (default: 10000)
PORT=${PORT:-10000}
echo "Starting FastAPI Health Server on port $PORT..."
exec uvicorn server:app --host 0.0.0.0 --port "$PORT"
