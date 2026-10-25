# Online Vide Code Editor

An in-browser code editor and development environment with WebContainer runtime, Monaco editor, integrated terminal, and Ollama AI assistant.

## Features

- **In-Browser Execution**: Powered by WebAssembly and WebContainers for instant Node.js, React, Vue, Next.js, and Express apps.
- **Monaco Code Editor**: VS Code-powered editing experience with intelligent syntax highlighting and AI inline completion.
- **Interactive Terminal**: Full xterm.js terminal connected directly to your browser-isolated container.
- **AI Assistant**: Built-in Ollama chat assistant and context-aware code completion.
- **Authentication**: Seamless GitHub and Google OAuth powered by NextAuth v5 (Auth.js) and Prisma ORM.
- **Database**: Cloud MongoDB Atlas integration for user profiles, saved playgrounds, star marks, and chat history.

## Getting Started

1. Clone and install dependencies:
```bash
npm install
```

2. Set up environment variables in `.env`:
```env
DATABASE_URL="mongodb+srv://..."
AUTH_SECRET="your_secret"
AUTH_GITHUB_ID=""
AUTH_GITHUB_SECRET=""
AUTH_GOOGLE_ID=""
AUTH_GOOGLE_SECRET=""
OLLAMA_API_KEY=""
```

3. Sync database models:
```bash
npx prisma db push
```

4. Start development server:
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.
