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

# Clean up stale PID files
rm -f /root/.hermes/whatsapp/session/bridge.pid /root/.hermes/whatsapp/session/.bridge*

# Restore WhatsApp credentials from Secret Files, backups, or environment
python3 -c "
import os, io, tarfile, base64, shutil

dest = '/root/.hermes/whatsapp/session'
os.makedirs(dest, exist_ok=True)

restored = False
secrets_dir = '/etc/secrets'

# 1. Check all files in /etc/secrets
if os.path.exists(secrets_dir):
    for fname in os.listdir(secrets_dir):
        fpath = os.path.join(secrets_dir, fname)
        if not os.path.isfile(fpath):
            continue
        try:
            with open(fpath, 'rb') as f:
                raw = f.read()
            if not raw:
                continue
            
            # Case A: creds.json or other json file
            if fname.endswith('.json') or raw.strip().startswith(b'{'):
                target_name = fname if fname.endswith('.json') else 'creds.json'
                with open(os.path.join(dest, target_name), 'wb') as out:
                    out.write(raw)
                print(f'✓ Restored {target_name} from {fname}')
                restored = True
                continue

            # Case B: Gzip tarball (binary magic \x1f\x8b)
            if raw.startswith(b'\x1f\x8b'):
                with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as tar:
                    tar.extractall(path=dest)
                print(f'✓ Restored session archive from {fname}')
                restored = True
                continue

            # Case C: Base64 encoded tarball or json
            try:
                cleaned = raw.strip().strip(b'\"\'').replace(b'\n', b'').replace(b'\r', b'').replace(b' ', b'')
                if cleaned.endswith(b'%'):
                    cleaned = cleaned[:-1]
                missing_padding = len(cleaned) % 4
                if missing_padding:
                    cleaned += b'=' * (4 - missing_padding)
                decoded = base64.b64decode(cleaned)
                if decoded.startswith(b'\x1f\x8b'):
                    with tarfile.open(fileobj=io.BytesIO(decoded), mode='r:gz') as tar:
                        tar.extractall(path=dest)
                    print(f'✓ Restored base64 archive from {fname}')
                    restored = True
                elif decoded.strip().startswith(b'{'):
                    with open(os.path.join(dest, 'creds.json'), 'wb') as out:
                        out.write(decoded)
                    print(f'✓ Restored base64 creds.json from {fname}')
                    restored = True
            except Exception as e:
                print(f'Note: Could not decode base64 from {fname}: {e}')
        except Exception as e:
            print(f'Error processing {fname}: {e}')

# 2. Check backup archive in /app
backup_tar = '/app/whatsapp_session_backup.tar.gz'
if not restored and os.path.exists(backup_tar):
    try:
        with tarfile.open(backup_tar, 'r:gz') as tar:
            tar.extractall(path=dest)
        print('✓ Restored session from /app backup tarball')
        restored = True
    except Exception as e:
        print(f'Note: backup tarball error: {e}')

# 3. Check environment variables
env_creds = os.environ.get('WHATSAPP_CREDS_JSON', '').strip()
env_b64 = os.environ.get('WHATSAPP_SESSION_B64', '').strip()
if not restored and env_creds:
    try:
        with open(os.path.join(dest, 'creds.json'), 'w') as f:
            f.write(env_creds)
        print('✓ Restored creds.json from WHATSAPP_CREDS_JSON env')
        restored = True
    except Exception as e:
        print(f'Error writing WHATSAPP_CREDS_JSON: {e}')

if not restored and env_b64:
    try:
        cleaned = env_b64.strip('\"\'\n\r ').replace('\n', '').replace('\r', '').replace(' ', '')
        if cleaned.endswith('%'): cleaned = cleaned[:-1]
        pad = len(cleaned) % 4
        if pad: cleaned += '=' * (4 - pad)
        decoded = base64.b64decode(cleaned)
        if decoded.startswith(b'\x1f\x8b'):
            with tarfile.open(fileobj=io.BytesIO(decoded), mode='r:gz') as tar:
                tar.extractall(path=dest)
            print('✓ Restored session from WHATSAPP_SESSION_B64 env')
            restored = True
    except Exception as e:
        print(f'Error decoding WHATSAPP_SESSION_B64: {e}')

if not restored:
    print('ℹ No saved WhatsApp session found.')
"

# Clean up any stale PID files copied from archives
rm -f /root/.hermes/whatsapp/session/bridge.pid /root/.hermes/whatsapp/session/.bridge*

# Patch hermes_constants.py to use system Node.js and bypass PM runtime downloads
python3 -c "
path = '/app/hermes-agent/hermes_constants.py'
if os.path.exists(path):
    with open(path, 'r') as f:
        code = f.read()

    # 1. Patch find_node_executable
    old_fn = 'def find_node_executable(command: str) -> str | None:'
    new_fn = '''def find_node_executable(command: str) -> str | None:
    found = shutil.which(command)
    if found:
        return found'''
    if old_fn in code:
        code = code.replace(old_fn, new_fn, 1)

    # 2. Patch with_hermes_node_path
    import re
    code = re.sub(
        r'def with_hermes_node_path\(env: dict\[str, str\] \| None = None\) -> dict\[str, str\]:.*?(?=\ndef )',
        'def with_hermes_node_path(env: dict[str, str] | None = None) -> dict[str, str]:\n    return dict(os.environ) if env is None else dict(env)\n',
        code,
        flags=re.DOTALL
    )

    with open(path, 'w') as f:
        f.write(code)
    print('✓ Patched Hermes constants to use system Node (/usr/bin/node)')
"

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
  reasoning_effort: low
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

# 4. Start Hermes WhatsApp Gateway in background with supervision loop
echo "Starting Hermes Gateway..."
mkdir -p /var/log
export PYTHONPATH="/app/hermes-agent:${PYTHONPATH}"

(
  while true; do
    echo "[$(date -u)] Starting Hermes Gateway..." >> /var/log/hermes-gateway.log
    cd /app/hermes-agent
    python3 -m hermes_cli.main gateway run >> /var/log/hermes-gateway.log 2>&1 || true
    echo "[$(date -u)] Hermes Gateway exited with code $?, restarting in 3s..." >> /var/log/hermes-gateway.log
    sleep 3
  done
) &

# 5. Start HTTP Healthcheck and AGY API server on Render PORT (default: 10000)
PORT=${PORT:-10000}
echo "Starting FastAPI Health Server on port $PORT..."
exec uvicorn server:app --host 0.0.0.0 --port "$PORT"
