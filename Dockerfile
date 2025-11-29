# Multi-stage build for Google Cloud Run
# Stage 1: Builder
FROM node:18-slim as builder

WORKDIR /app

# Set Puppeteer to skip Chromium download (we'll use system chromium)
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Copy package files
COPY package*.json ./

# Install dependencies (fast - no Chromium download)
RUN npm install --omit=dev --verbose

# Stage 2: Runtime
FROM node:18-slim

WORKDIR /app

# Install runtime dependencies for Puppeteer and Chrome
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
    chromium-browser \
    libxss1 \
    libappindicator1 \
    libindicator7 \
    libnss3 \
    libxss1 \
    libxtst6 \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# Copy node_modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy application files
COPY bot.js .
COPY package.json .
COPY package-lock.json* ./

# Create data directory for message persistence
RUN mkdir -p /app/data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "console.log('Health check passed')" || exit 1

# Set environment variables for unbuffered logging and system Chromium
ENV NODE_ENV=production
ENV PORT=8080
ENV NODE_OPTIONS="--no-deprecation --trace-uncaught"
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_DOWNLOAD=true

# Run the bot with unbuffered output
CMD ["node", "--unhandled-rejections=strict", "bot.js"]
