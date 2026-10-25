# Production & AWS Deployment Guide: Chai Vibe Code Editor

This document outlines the **architecture, production-readiness setup, AWS hosting strategies, and a complete checklist of action items required from your side** to deploy this full-stack WebContainer Code Editor to production.

---

## 1. Project Readiness Status

| Component | Status | Details |
|---|---|---|
| **Framework** | ✅ Production Ready | Next.js 15.5.2 (Turbopack) with App Router |
| **Output Target** | ✅ Configured | Standalone mode (`output: "standalone"`) in `next.config.ts` |
| **Containerization** | ✅ Configured | Multi-stage production `Dockerfile`, `.dockerignore`, & `docker-compose.yml` |
| **Database** | ✅ Verified & Synced | MongoDB Atlas via Prisma ORM 6.15.0 with full schemas (`User`, `Account`, `Playground`, `StarMark`, `TemplateFile`, `ChatMessage`) |
| **Auth** | ✅ Configured | NextAuth v5 (`@auth/prisma-adapter`) with JWT session strategy |
| **Cross-Origin Isolation** | ✅ Configured | COOP (`same-origin`) & COEP (`require-corp`) headers enabled for WebContainers |
| **AI Integration** | ✅ Dual Support | Ollama Cloud (`OLLAMA_API_KEY`) and local/EC2 self-hosted (`OLLAMA_HOST`) |
| **Health Check** | ✅ Implemented | `/api/health` endpoint with active MongoDB ping for AWS load balancers |

---

## 2. Checklist: What Needs to Be Done on Your Side

Before launching to AWS, you need to acquire/configure these external services:

### A. OAuth Applications (GitHub & Google)
In production, your OAuth callbacks must point to your live domain instead of `localhost:3000`.

1. **GitHub OAuth App**:
   - Go to [GitHub Developer Settings](https://github.com/settings/developers) $\rightarrow$ **OAuth Apps** $\rightarrow$ **New OAuth App**.
   - **Homepage URL**: `https://your-domain.com`
   - **Authorization callback URL**: `https://your-domain.com/api/auth/callback/github`
   - Generate Client Secret and save `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`.

2. **Google Cloud OAuth 2.0 Client**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
   - Configure **OAuth Consent Screen**.
   - Create **OAuth client ID** (Application type: *Web application*).
   - **Authorized JavaScript origins**: `https://your-domain.com`
   - **Authorized redirect URIs**: `https://your-domain.com/api/auth/callback/google`
   - Save `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.

### B. MongoDB Atlas Network Access
- Go to [MongoDB Atlas](https://cloud.mongodb.com/) $\rightarrow$ **Network Access**.
- Add your AWS Server IP or Elastic IP (or `0.0.0.0/0` with strong password authentication).
- Verify database name (`code-editor`) is included in your `DATABASE_URL`.

### C. Domain Name & SSL Certificate
- WebContainers **strictly require HTTPS** (secure context) to initialize SharedArrayBuffer.
- Use **AWS Route 53** or **Cloudflare** for DNS.
- Use **AWS Certificate Manager (ACM)** (free SSL with AWS load balancers) or **Let's Encrypt / Certbot** if using EC2 directly.

### D. AI Model Key (Ollama)
Choose one of the following two deployment models:
- **Option 1 (Easiest - Ollama Cloud)**:
  - Generate an API key from [Ollama Cloud](https://ollama.com).
  - Set `OLLAMA_API_KEY="your_key"` and `OLLAMA_MODEL="gpt-oss:20b-cloud"`.
- **Option 2 (Self-Hosted on AWS)**:
  - Run Ollama on an AWS EC2 instance (e.g. `g4dn.xlarge` with NVIDIA GPU or `t3.xlarge` CPU for smaller models like `qwen2.5-coder:1.5b`).
  - Set `OLLAMA_HOST="http://<internal-ec2-ip>:11434"`.

---

## 3. Environment Variables Reference

Configure these in AWS (App Runner Environment or EC2 `.env`):

```bash
# Production URL & Auth
NEXTAUTH_URL="https://your-domain.com"
AUTH_SECRET="866579fc95d820df3890f5cfa2c300ff01f92e4be5cd7b9b045e051c9dca8b99"
NODE_ENV="production"
PORT=3000

# MongoDB Database Connection
DATABASE_URL="mongodb+srv://<username>:<password>@code-editor.rgubtze.mongodb.net/code-editor?retryWrites=true&w=majority"

# GitHub OAuth
GITHUB_CLIENT_ID="your_github_client_id"
GITHUB_CLIENT_SECRET="your_github_client_secret"

# Google OAuth
GOOGLE_CLIENT_ID="your_google_client_id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your_google_client_secret"

# Ollama AI Configuration
OLLAMA_HOST="https://ollama.com"
OLLAMA_API_KEY="your_ollama_cloud_api_key"
OLLAMA_MODEL="gpt-oss:20b-cloud"
```

---

## 4. Recommended AWS Hosting Architectures

### Strategy A: AWS App Runner (Recommended — Fully Managed & Auto-Scaled)
AWS App Runner is AWS's modern container platform. It requires zero infrastructure maintenance, handles auto-scaling, and provisions HTTPS certificates automatically.

```
[ User Browser ]
       │  (HTTPS)
       ▼
[ AWS App Runner ] ──► Runs Standalone Docker Container (Next.js 15)
       │
       ├──► MongoDB Atlas (Data & Auth Storage)
       └──► Ollama Cloud (AI Chat & Code Completion)
```

#### Steps to Deploy on AWS App Runner:
1. **Push your code to GitHub** (already done on `master`).
2. Open **AWS Console** $\rightarrow$ Search **App Runner** $\rightarrow$ **Create service**.
3. **Source**: Choose **Source code repository** $\rightarrow$ Connect your GitHub account $\rightarrow$ Select `online-vide-code-editor` and branch `master`.
4. **Build settings**: Select **Use a configuration file** or configure via console:
   - Runtime: `Nodejs 20`
   - Build command: `npm install && npx prisma generate && npm run build`
   - Start command: `node .next/standalone/server.js`
   - Port: `3000`
5. **Environment Variables**: Add the variables from Section 3.
6. **Health Check**:
   - Protocol: `HTTP`
   - Path: `/api/health`
7. Click **Deploy**. App Runner will deploy your application and provide a public HTTPS URL.
8. Add your custom domain under **Custom domains** tab in App Runner.

---

### Strategy B: AWS EC2 (Ubuntu 24.04 LTS with Docker & Nginx)
Best if you want total control, lower fixed monthly pricing, or want to host Ollama directly on the same virtual server.

#### 1. Launch EC2 Instance:
- **AMI**: Ubuntu Server 24.04 LTS (x86_64)
- **Instance Type**: `t3.medium` (minimum for Next.js builds) or `t3.large`
- **Storage**: 30 GB gp3 SSD
- **Security Group Inbound Rules**:
  - Port `22` (SSH) — your IP
  - Port `80` (HTTP) — `0.0.0.0/0`
  - Port `443` (HTTPS) — `0.0.0.0/0`

#### 2. Install Docker & Git on EC2:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 3. Clone Repository & Setup Environment:
```bash
git clone https://github.com/manoj-yg/online-vide-code-editor.git
cd online-vide-code-editor
nano .env # Paste your production environment variables
```

#### 4. Run with Docker Compose:
```bash
docker-compose up -d --build
```

#### 5. Configure Nginx Reverse Proxy with SSL:
Install Nginx and Certbot:
```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

Create `/etc/nginx/sites-available/code-editor`:
```nginx
server {
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # Required for WebContainers & SharedArrayBuffer
        add_header Cross-Origin-Opener-Policy "same-origin" always;
        add_header Cross-Origin-Embedder-Policy "require-corp" always;
    }
}
```

Enable site and generate free Let's Encrypt SSL:
```bash
sudo ln -s /etc/nginx/sites-available/code-editor /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo certbot --nginx -d your-domain.com
```

---

## 5. Critical Technical Considerations for This Application

1. **WebContainers in Production**:
   - WebContainers run a WebAssembly Node.js runtime inside the browser.
   - They **require cross-origin isolation**. If any third-party asset (image, font, script) loaded in the page fails CORS (`require-corp`), the browser will refuse to load it. Keep images hosted on domains that send `Cross-Origin-Resource-Policy: cross-origin` (GitHub and Google avatar CDNs are already configured in `next.config.ts`).

2. **MongoDB Connection Pooling in Serverless / Container Environments**:
   - `lib/db.ts` uses the global singleton pattern (`globalThis.prisma`) which prevents connection pool exhaustion across Next.js re-renders.
   - In MongoDB Atlas, keep an eye on active connections under the cluster metrics tab.

3. **CI/CD Automation (GitHub Actions)**:
   - You can add `.github/workflows/deploy.yml` to automatically build and deploy whenever you push to `master`.

---

## 6. Verification Steps After Deployment

Once deployed to your domain:
1. Visit `https://your-domain.com/api/health` $\rightarrow$ Confirm response is `{"status":"healthy","database":"connected"}`.
2. Visit `https://your-domain.com/auth/sign-in` $\rightarrow$ Sign in with GitHub and Google OAuth.
3. Open `https://your-domain.com/dashboard` $\rightarrow$ Create a new playground (e.g., React or Vite starter).
4. Inside the editor:
   - Test terminal command execution in WebContainer (`npm install`, `npm run dev`).
   - Open AI Assistant panel $\rightarrow$ Send a prompt $\rightarrow$ Confirm Ollama responds.
   - Type code in Monaco editor $\rightarrow$ Confirm inline completion triggers.
