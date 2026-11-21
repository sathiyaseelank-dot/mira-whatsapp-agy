import os
import io
import tarfile
import shutil
import base64
import subprocess
from fastapi import FastAPI, HTTPException, Request, Header
from pydantic import BaseModel

app = FastAPI(title="Mira WhatsApp + Antigravity (AGY) Service")

class AgyRequest(BaseModel):
    prompt: str
    timeout_seconds: int = 180

class HFSpaceRequest(BaseModel):
    space_name: str
    sdk: str = "gradio"
    app_code: str
    requirements: str = ""

@app.get("/")
@app.get("/health")
@app.head("/")
@app.head("/health")
def health():
    """Healthcheck endpoint for Render and 24/7 keep-alive pingers."""
    return {
        "status": "online",
        "service": "mira-whatsapp-agy",
        "agy": "installed",
        "hermes": "running"
    }

@app.get("/debug/status")
def debug_status():
    """Diagnostic endpoint to inspect session files, secrets, and Hermes process/logs."""
    session_dir = "/root/.hermes/whatsapp/session"
    secrets_dir = "/etc/secrets"
    
    session_files = os.listdir(session_dir) if os.path.exists(session_dir) else []
    secret_files = []
    if os.path.exists(secrets_dir):
        for f in os.listdir(secrets_dir):
            fp = os.path.join(secrets_dir, f)
            size = os.path.getsize(fp) if os.path.isfile(fp) else 0
            try:
                with open(fp, "rb") as sf:
                    preview = sf.read(30).hex()
            except Exception:
                preview = "unreadable"
            secret_files.append({"name": f, "size_bytes": size, "magic_hex": preview})

    ps = subprocess.run(["ps", "aux"], capture_output=True, text=True).stdout
    hermes_procs = [line for line in ps.splitlines() if "hermes" in line or "node" in line or "bridge" in line]

    bridge_log_path = "/root/.hermes/whatsapp/bridge.log"
    bridge_log = ""
    if os.path.exists(bridge_log_path):
        try:
            with open(bridge_log_path, "r", errors="ignore") as bl:
                bridge_log = "".join(bl.readlines()[-30:])
        except Exception:
            pass

    gw_log_path = "/var/log/hermes-gateway.log"
    gw_log = ""
    if os.path.exists(gw_log_path):
        try:
            with open(gw_log_path, "r", errors="ignore") as gwf:
                gw_log = "".join(gwf.readlines()[-40:])
        except Exception:
            pass

    return {
        "secrets": secret_files,
        "session_files_count": len(session_files),
        "session_has_creds": os.path.exists(os.path.join(session_dir, "creds.json")),
        "sample_session_files": session_files[:15],
        "hermes_processes": hermes_procs,
        "gateway_log_tail": gw_log,
        "bridge_log_tail": bridge_log
    }

@app.post("/session/sync")
async def sync_session(request: Request, authorization: str = Header(None)):
    """Upload WhatsApp session tar.gz or creds.json directly and restart Hermes bridge."""
    expected_token = os.environ.get("GROQ_API_KEY", "") or os.environ.get("HF_TOKEN", "")
    if not authorization or (expected_token and expected_token not in authorization):
        raise HTTPException(status_code=401, detail="Unauthorized")

    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail="Empty body")

    dest = "/root/.hermes/whatsapp/session"
    os.makedirs(dest, exist_ok=True)

    restored = []
    # 1. Gzip tarball
    if body.startswith(b'\x1f\x8b'):
        with tarfile.open(fileobj=io.BytesIO(body), mode='r:gz') as tar:
            tar.extractall(path=dest)
            restored = tar.getnames()
    # 2. Plain JSON
    elif body.strip().startswith(b'{'):
        with open(os.path.join(dest, "creds.json"), "wb") as f:
            f.write(body)
        restored = ["creds.json"]
    # 3. Base64 encoded
    else:
        try:
            cleaned = body.strip().strip(b'\"\'').replace(b'\n', b'').replace(b'\r', b'').replace(b' ', b'')
            if cleaned.endswith(b'%'):
                cleaned = cleaned[:-1]
            pad = len(cleaned) % 4
            if pad:
                cleaned += b'=' * (4 - pad)
            decoded = base64.b64decode(cleaned)
            if decoded.startswith(b'\x1f\x8b'):
                with tarfile.open(fileobj=io.BytesIO(decoded), mode='r:gz') as tar:
                    tar.extractall(path=dest)
                    restored = tar.getnames()
            elif decoded.strip().startswith(b'{'):
                with open(os.path.join(dest, "creds.json"), "wb") as f:
                    f.write(decoded)
                restored = ["creds.json"]
            else:
                raise ValueError("Payload not recognized as gzip tar or JSON")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to parse session data: {e}")

    # Remove stale pidfiles from sync
    for stale in ["bridge.pid", ".bridge.env-fingerprint", ".bridge.pid"]:
        stale_file = os.path.join(dest, stale)
        if os.path.exists(stale_file):
            try:
                os.remove(stale_file)
            except Exception:
                pass

    # Back up to /app for quick recovery
    try:
        shutil.make_archive("/app/whatsapp_session_backup", "gztar", dest)
    except Exception:
        pass

    # Restart Hermes Gateway
    restart_msg = "Restart initiated"
    try:
        subprocess.run(["pkill", "-9", "-f", "hermes_cli.main gateway"], check=False)
        subprocess.run(["pkill", "-9", "-f", "bridge.js"], check=False)
    except Exception as e:
        restart_msg = f"Restart error: {e}"

    return {
        "status": "success",
        "restored_files_count": len(restored),
        "files_sample": restored[:15],
        "hermes": restart_msg
    }

@app.post("/agy/run")
def run_agy(req: AgyRequest):
    """Execute an Antigravity prompt non-interactively in headless mode."""
    if not req.prompt:
        raise HTTPException(status_code=400, detail="Prompt is required")
    
    cmd = [
        "agy",
        "-p", req.prompt,
        "--dangerously-skip-permissions",
        "--output-format", "text"
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=req.timeout_seconds,
            cwd="/app/workspace"
        )
        return {
            "exit_code": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip()
        }
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Antigravity task timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/hf/create-space")
def create_hf_space(req: HFSpaceRequest):
    """Directly create and deploy a project to Hugging Face Spaces."""
    hf_token = os.environ.get("HF_TOKEN")
    if not hf_token:
        raise HTTPException(status_code=400, detail="HF_TOKEN environment variable not set")
    
    try:
        from huggingface_hub import HfApi
        api = HfApi(token=hf_token)
        user = api.whoami().get("name")
        repo_id = f"{user}/{req.space_name}"
        
        # 1. Create Space repo
        api.create_repo(
            repo_id=repo_id,
            repo_type="space",
            space_sdk=req.sdk,
            exist_ok=True
        )
        
        # 2. Upload app.py
        api.upload_file(
            path_or_fileobj=req.app_code.encode("utf-8"),
            path_in_repo="app.py",
            repo_id=repo_id,
            repo_type="space"
        )
        
        # 3. Upload requirements.txt if provided
        if req.requirements:
            api.upload_file(
                path_or_fileobj=req.requirements.encode("utf-8"),
                path_in_repo="requirements.txt",
                repo_id=repo_id,
                repo_type="space"
            )
            
        space_url = f"https://huggingface.co/spaces/{repo_id}"
        return {
            "status": "success",
            "repo_id": repo_id,
            "space_url": space_url
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
