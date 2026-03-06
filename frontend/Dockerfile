FROM node:18-alpine

WORKDIR /app

# Install live-server globally
RUN npm install -g live-server

# Copy all frontend files
COPY . .

EXPOSE 3000

CMD ["live-server", "--port=3000", "--host=0.0.0.0"]
