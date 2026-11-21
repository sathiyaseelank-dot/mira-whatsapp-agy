import os
import subprocess
from fastapi import FastAPI, HTTPException
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
def health():
    """Healthcheck endpoint for Render and 24/7 keep-alive pingers."""
    return {
        "status": "online",
        "service": "mira-whatsapp-agy",
        "agy": "installed",
        "hermes": "running"
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
            "url": space_url
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
