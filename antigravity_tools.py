import os
import subprocess
from tools.registry import registry, tool_error, tool_result

def run_antigravity_handler(args, **kwargs):
    """Handler for run_antigravity tool."""
    prompt = args.get("prompt", "").strip()
    if not prompt:
        return tool_error("Prompt is required.")

    cmd = [
        "agy",
        "-p", prompt,
        "--model", "gemini-3.8-flash-high",
        "--dangerously-skip-permissions",
        "--output-format", "text"
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=180,
            cwd="/app/workspace"
        )
        out = proc.stdout.strip()
        err = proc.stderr.strip()
        if proc.returncode == 0:
            return tool_result(f"Antigravity CLI output:\n{out}")
        else:
            return tool_result(f"Antigravity CLI finished with status {proc.returncode}:\n{out}\nError details:\n{err}")
    except subprocess.TimeoutExpired:
        return tool_error("Antigravity task timed out after 3 minutes.")
    except Exception as e:
        return tool_error(f"Failed to execute Antigravity CLI: {e}")

def deploy_hf_space_handler(args, **kwargs):
    """Handler for deploy_hf_space tool."""
    space_name = args.get("space_name", "").strip()
    app_code = args.get("app_code", "").strip()
    sdk = args.get("sdk", "gradio").strip()
    requirements = args.get("requirements", "").strip()

    if not space_name or not app_code:
        return tool_error("space_name and app_code are required.")

    hf_token = os.environ.get("HF_TOKEN")
    if not hf_token:
        return tool_error("HF_TOKEN environment variable is not configured.")

    try:
        from huggingface_hub import HfApi
        api = HfApi(token=hf_token)
        user = api.whoami().get("name")
        repo_id = f"{user}/{space_name}"

        api.create_repo(
            repo_id=repo_id,
            repo_type="space",
            space_sdk=sdk,
            exist_ok=True
        )
        api.upload_file(
            path_or_fileobj=app_code.encode("utf-8"),
            path_in_repo="app.py",
            repo_id=repo_id,
            repo_type="space"
        )
        if requirements:
            api.upload_file(
                path_or_fileobj=requirements.encode("utf-8"),
                path_in_repo="requirements.txt",
                repo_id=repo_id,
                repo_type="space"
            )

        space_url = f"https://huggingface.co/spaces/{repo_id}"
        return tool_result(f"Successfully created and deployed Hugging Face Space: {space_url}")
    except Exception as e:
        return tool_error(f"Failed to deploy Hugging Face Space: {e}")

# Register run_antigravity
registry.register(
    name="run_antigravity",
    toolset="antigravity",
    schema={
        "name": "run_antigravity",
        "description": "Run Google Antigravity CLI (agy) agent to autonomously build apps, solve coding tasks, generate code, or execute complex commands.",
        "parameters": {
            "type": "object",
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": "Detailed prompt describing what Antigravity CLI agent should code or build."
                }
            },
            "required": ["prompt"]
        }
    },
    handler=run_antigravity_handler
)

# Register deploy_hf_space
registry.register(
    name="deploy_hf_space",
    toolset="antigravity",
    schema={
        "name": "deploy_hf_space",
        "description": "Directly create and deploy a brand new project to Hugging Face Spaces (e.g. Gradio or Streamlit web app).",
        "parameters": {
            "type": "object",
            "properties": {
                "space_name": {
                    "type": "string",
                    "description": "Name for the Hugging Face space repository (e.g. 'tamil-translator', 'calculator-app')"
                },
                "sdk": {
                    "type": "string",
                    "enum": ["gradio", "streamlit", "docker", "static"],
                    "description": "Space framework/SDK. Default: gradio"
                },
                "app_code": {
                    "type": "string",
                    "description": "Complete Python source code for app.py"
                },
                "requirements": {
                    "type": "string",
                    "description": "Optional contents for requirements.txt (e.g. 'requests\ntransformers')"
                }
            },
            "required": ["space_name", "app_code"]
        }
    },
    handler=deploy_hf_space_handler
)
