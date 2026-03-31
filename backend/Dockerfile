# Multi-stage build for optimized production image
# Stage 1: Build stage
FROM node:18-alpine3.19 AS builder

LABEL maintainer="DevOps Team"
LABEL description="Student Portal Backend - Build Stage"

WORKDIR /build

# Copy package files
COPY package*.json ./

# Install dependencies with production flag
RUN npm ci --only=production && \
    npm cache clean --force

# Cache bust node_modules for next stage
RUN find node_modules -name "*.d.ts" -delete && \
    find node_modules -name "*.md" -delete && \
    find node_modules -name "*.map" -delete

# Stage 2: Runtime stage
FROM node:18-alpine3.19

LABEL maintainer="DevOps Team"
LABEL description="Student Portal Backend - Runtime"
LABEL version="1.0.0"

WORKDIR /app

# Create non-root user for running app
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init=1.2.5-r1

# Copy only production dependencies from builder
COPY --from=builder --chown=appuser:appuser /build/node_modules ./node_modules

# Copy application code
COPY --chown=appuser:appuser . .

# Ensure node_modules is read-only
RUN chmod -R 555 node_modules

# Set environment
ENV NODE_ENV=production \
    NODE_OPTIONS="--enable-source-maps --max-old-space-size=512"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:5000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Expose port
EXPOSE 5000

# Switch to non-root user
USER appuser

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/sbin/dumb-init", "--"]

# Start application
CMD ["node", "server.js"]
