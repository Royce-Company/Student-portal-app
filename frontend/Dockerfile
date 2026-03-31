# Multi-stage build for optimized production image
# Stage 1: Build stage (optional - if you add any build process)
FROM node:18-alpine3.19 AS builder

LABEL maintainer="DevOps Team"
LABEL description="Student Portal Frontend - Build Stage"

WORKDIR /build

# Copy application files
COPY . .

# Optionally: minify CSS and HTML
# RUN npm install terser
# RUN npm install postcss postcss-cli cssnano

# Stage 2: Runtime stage with nginx
FROM nginx:1.25-alpine

LABEL maintainer="DevOps Team"
LABEL description="Student Portal Frontend - Runtime"
LABEL version="1.0.0"

# Install curl for health checks
RUN apk add --no-cache curl=8.5.0-r0 dumb-init=1.2.5-r1

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-default.conf /etc/nginx/conf.d/default.conf

# Copy frontend files from builder or directly
COPY --chown=appuser:appuser . /usr/share/nginx/html/

# Set permissions
RUN chmod -R 755 /usr/share/nginx/html && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    chmod 777 /var/run

# Create nginx runtime directory
RUN chown -R appuser:appuser /etc/nginx && \
    touch /var/run/nginx.pid && \
    chown appuser:appuser /var/run/nginx.pid

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Expose port
EXPOSE 3000

# Switch to non-root user
USER appuser

# Use dumb-init to handle signals properly
ENTRYPOINT ["/sbin/dumb-init", "--"]

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
