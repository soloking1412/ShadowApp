# Relayer Dockerfile - Optional auto-reveal service
FROM node:20-alpine

WORKDIR /app

# Install dependencies
RUN npm init -y && \
    npm install ethers@6 dotenv

# Copy relayer script
COPY relayer.js ./

CMD ["node", "relayer.js"]
