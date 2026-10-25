# ----------------------------------------------------
# Base image
# ----------------------------------------------------
FROM node:20-alpine AS base
RUN apk add --no-cache libc6-compat openssl
WORKDIR /app

# ----------------------------------------------------
# Dependencies stage
# ----------------------------------------------------
FROM base AS deps
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci

# ----------------------------------------------------
# Builder stage
# ----------------------------------------------------
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Build-time dummy defaults so standalone Next.js compilation succeeds in CI/Docker without external secrets
ARG DATABASE_URL="mongodb://127.0.0.1:27017/ci_build_dummy?directConnection=true"
ARG AUTH_SECRET="ci-dummy-secret-minimum-32-characters-for-build"
ENV DATABASE_URL=$DATABASE_URL
ENV AUTH_SECRET=$AUTH_SECRET

RUN npx prisma generate
RUN npm run build

# ----------------------------------------------------
# Production runner stage
# ----------------------------------------------------
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy static and starter assets
COPY --from=builder /app/public ./public
COPY --from=builder /app/starters ./starters

# Copy standalone build bundle
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
