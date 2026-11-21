# Mira WhatsApp + Antigravity (AGY) on Render

This repository contains everything needed to deploy **Mira (WhatsApp Bot)** with **Antigravity CLI (agy)** and **Hugging Face Space Builder** on **Render** for free.

---

## 💰 Is Render Free?
- **Yes.** Render provides a **Free Tier** for Web Services ($0/month).
- **Keep-Alive Note:** Render's free tier sleeps after 15 minutes of inactivity. Because this service has a `/health` endpoint, you can add your URL to a free pinging service (like [cron-job.org](https://cron-job.org) or UptimeRobot) to ping every 10 minutes. This keeps it running **24/7 for 100% free**.

---

## 🚀 Features
1. **WhatsApp AI Companion (Mira):**
   - Natural Tanglish conversation.
   - Empathetic companion that understands feelings.
   - Short, punchy 1–2 sentence human-like replies.
2. **Scheduled Global News:**
   - 8:00 AM & 8:00 PM IST global news briefing sent directly to your WhatsApp group.
3. **Headless Antigravity CLI (`agy`):**
   - Powered by Google Gemini API key (`GEMINI_API_KEY`).
   - Runs autonomous coding and execution tasks.
4. **Hugging Face Space Deployer:**
   - Deploys new Gradio/Docker spaces on Hugging Face using `HF_TOKEN`.

---

## 🔑 Required Environment Variables on Render

| Variable | Description | Where to get it |
| :--- | :--- | :--- |
| `GROQ_API_KEY` | Groq API key for fast inference (`openai/gpt-oss-120b`) | [console.groq.com](https://console.groq.com) |
| `GEMINI_API_KEY` | Google Gemini API key for Antigravity CLI (`agy`) | [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) |
| `HF_TOKEN` | Hugging Face Access Token (Write permissions) | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) |
| `WHATSAPP_SESSION_B64` | Base64 encoded WhatsApp Baileys session | Run the command below on your local PC |
| `WHATSAPP_HOME_CHANNEL` | *(Optional)* WhatsApp Group JID (or type `/sethome` in group) | Auto-configured via `/sethome` |

### How to get your `WHATSAPP_SESSION_B64`:
Run this single command in your terminal on this computer:
```bash
tar -cz -C ~/.hermes/whatsapp/session . | base64 -w 0
```
Copy the output and paste it into the `WHATSAPP_SESSION_B64` field in Render.

---

## 📦 How to Deploy to Render

1. **Push this folder to a GitHub repository:**
   ```bash
   cd "/home/inkyank-01/Desktop/distributed llm/render-mira-agy"
   git init
   git add .
   git commit -m "Deploy Mira WhatsApp and Antigravity to Render"
   git remote add origin https://github.com/<your-username>/<your-repo-name>.git
   git branch -M main
   git push -u origin main
   ```

2. **Create Web Service on Render:**
   - Go to [dashboard.render.com](https://dashboard.render.com).
   - Click **New +** -> **Web Service**.
   - Connect your GitHub repository.
   - Select **Runtime: Docker**.
   - Select **Instance Type: Free**.

3. **Add Environment Variables:**
   - Add the 4 environment variables listed in the table above.
   - Click **Create Web Service**.

4. **Keep it 24/7 Awake:**
   - Once Render finishes deploying, copy your URL (e.g. `https://mira-whatsapp-agy.onrender.com`).
   - Go to [cron-job.org](https://cron-job.org) (free account).
   - Create a cron job to make a `GET` request to:
     `https://mira-whatsapp-agy.onrender.com/health`
     every **10 minutes**.
   - Your bot will stay awake and running 24/7!
