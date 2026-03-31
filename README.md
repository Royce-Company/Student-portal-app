# 🎓 Student Portal - Production-Ready DevOps Platform on AWS EKS

A modern, full-stack student management system built with Node.js, Express, MySQL, and vanilla JavaScript. Production-ready deployment on AWS EKS with comprehensive CI/CD, monitoring, and infrastructure automation using Terraform.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Node](https://img.shields.io/badge/node-%3E%3D14.0.0-brightgreen.svg)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.5.0-purple.svg)
![Kubernetes](https://img.shields.io/badge/kubernetes-%3E%3D1.26-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment](#deployment)
- [Infrastructure](#infrastructure)
- [Monitoring](#monitoring)
- [CI/CD](#cicd)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

### Application Features
- 🎨 Modern dark-themed UI with glassmorphism effects
- 🔐 Secure JWT-based authentication
- 👤 User profile management
- 📊 Interactive dashboard with statistics
- 🎯 Role-based access control (Student, Teacher, Admin)
- 📱 Fully responsive design

### DevOps & Infrastructure
- ☁️ **AWS EKS**: Enterprise-grade Kubernetes cluster
- 🏗️ **Terraform**: Complete Infrastructure as Code
- 📦 **Docker**: Containerized backend and frontend
- 🚀 **CI/CD**: Automated GitHub Actions pipelines
- 📊 **Monitoring**: Prometheus, Grafana, Loki, Tempo
- 🔒 **Security**: Network policies, RBAC, secrets management
- 🛡️ **Backups**: Automated RDS backups and recovery
- 🔄 **Auto-scaling**: Horizontal and vertical scaling

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI/CD                      │
├─────────────────────────────────────────────────────────────┤
│  Docker Build → ECR Push → Helm Deploy → Integration Tests   │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
┌───────▼─────────┐          ┌───────────▼──────────┐
│   AWS EKS       │          │   AWS RDS MySQL      │
│  ┌───────────┐  │          │  ┌─────────────────┐ │
│  │  Backend  │  │          │  │  student_app    │ │
│  │ (Replicas)│  │          │  │  (Multi-AZ)     │ │
│  └───────────┘  │          │  └─────────────────┘ │
│  ┌───────────┐  │          │  ┌─────────────────┐ │
│  │ Frontend  │  │          │  │  Backups (30d)  │ │
│  │ (Replicas)│  │          │  └─────────────────┘ │
│  └───────────┘  │          └──────────────────────┘
│  ┌───────────┐  │
│  │ Ingress   │  │
│  │  + TLS    │  │
│  └───────────┘  │
└────────────────┘
        │
    ┌───┴────────────────────────────────┐
    │                                    │
┌───▼──────────────┐          ┌──────────▼──────────┐
│ Monitoring Stack │          │  CloudWatch Logs    │
│ ┌──────────────┐ │          │ ┌─────────────────┐ │
│ │ Prometheus   │ │          │ │ Pod Logs        │ │
│ │ Grafana      │ │          │ │ EKS Logs        │ │
│ │ Loki         │ │          │ │ RDS Logs        │ │
│ │ AlertManager │ │          │ └─────────────────┘ │
│ └──────────────┘ │          └─────────────────────┘
└──────────────────┘
```

## 📦 Prerequisites

### Required
- AWS account with appropriate permissions
- [Terraform](https://www.terraform.io/downloads) v1.5.0+
- [AWS CLI](https://aws.amazon.com/cli/) v2
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.26+
- [Helm](https://helm.sh/docs/intro/install/) v3.0+
- [Git](https://git-scm.com/)
- [Docker](https://www.docker.com/) (for local development)

### AWS Requirements
- VPC and subnets configured
- IAM permissions for EKS, RDS, ECR, S3
- Route53 hosted zone for domain
- Certificate setup for HTTPS

### GitHub Requirements
- GitHub repository
- GitHub Actions enabled
- OIDC configured for AWS integration

## 🚀 Quick Start (Local Development)

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/student-portal.git
cd student-portal
```

### 2. Backend Setup

```bash
cd backend
npm install
cp .env.example .env

# Update .env with your settings
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=student_app
JWT_SECRET=your_jwt_secret

npm run dev
```

### 3. Frontend Setup

```bash
cd frontend
# Frontend runs on http://localhost:3000
```

### 4. Docker Compose (All Services)

```bash
docker-compose up -d

# Access:
# Frontend: http://localhost:3000
# Backend:  http://localhost:5000
```

## 🌐 Deployment

### Production Deployment

Follow the [Production Deployment Guide](./PRODUCTION_DEPLOYMENT.md) for complete step-by-step instructions.

**Quick Steps:**

```bash
# 1. Deploy infrastructure
cd terraform/environments/production
terraform init
terraform apply -var-file=terraform.tfvars

# 2. Deploy application
helm install student-portal ./helm-charts/student-portal \
  --namespace student-portal \
  --create-namespace

# 3. Verify deployment
kubectl get pods -n student-portal
kubectl get svc -n student-portal
```

### Staging Deployment

```bash
cd terraform/environments/staging
terraform init
terraform apply -var-file=terraform.tfvars
```

## 🏗️ Infrastructure

### Terraform

Complete Infrastructure as Code for AWS EKS, RDS, VPC, and more.

```bash
# Directory structure
terraform/
├── main.tf              # Main resources
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Provider versions
├── modules/
│   ├── networking/      # VPC, subnets, security groups
│   ├── eks/            # EKS cluster and node groups
│   ├── rds/            # RDS MySQL database
│   ├── iam/            # IAM roles and policies
│   └── ecr/            # ECR repositories
└── environments/
    ├── production/     # Production configuration
    └── staging/        # Staging configuration
```

**See [Terraform Documentation](./terraform/README.md) for details**

### Kubernetes & Helm

Production-ready Helm charts with:
- Auto-scaling (HPA)
- Health checks (liveness, readiness, startup probes)
- Resource limits and requests
- Network policies
- RBAC
- Pod Disruption Budgets

```bash
helm-charts/
└── student-portal/
    ├── Chart.yaml
    ├── values.yaml               # Production values
    └── templates/
        ├── namespace.yaml        # RBAC and security
        ├── backend-deployment.yaml
        ├── frontend-deployment.yaml
        ├── ingress.yaml         # TLS enabled
        ├── servicemonitor.yaml  # Prometheus
        └── networkpolicy.yaml   # Security
```

**See [Helm Values](./helm-charts/student-portal/values.yaml) for all configuration options**

## 🚀 CI/CD

### GitHub Actions Workflows

Automated pipelines for building, testing, and deploying:

1. **Docker Build** (`.github/workflows/docker-build.yml`)
   - Build and push images to ECR
   - Scan images for vulnerabilities
   - Multi-stage Docker builds

2. **Deploy to EKS** (`.github/workflows/deploy-eks.yml`)
   - Automated Helm deployments
   - Rolling updates
   - Smoke tests
   - Slack notifications

3. **Terraform CI/CD** (`.github/workflows/terraform.yml`)
   - Plan and apply infrastructure changes
   - State locking
   - Plan artifacts

4. **Code Quality** (`.github/workflows/code-quality.yml`)
   - Trivy security scanning
   - ESLint and npm audit
   - Dockerfile linting
   - SBOM generation

5. **Integration Tests** (`.github/workflows/integration-tests.yml`)
   - Backend API tests
   - Frontend validation
   - Database connectivity

**See [Workflows Setup Guide](./.github/WORKFLOWS_SETUP.md) for configuration**

## 📊 Monitoring

### Stack Components

- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Loki**: Log aggregation
- **Tempo**: Distributed tracing
- **AlertManager**: Alert routing
- **CloudWatch**: AWS native monitoring

### Key Metrics

- Request rate, latency, error rate
- CPU and memory utilization
- Database connections and performance
- Pod restart rates
- Node capacity

**See [Monitoring Setup Guide](./MONITORING_SETUP.md) for installation and configuration**

## 🔒 Security

### Implemented Security Measures

- ✅ Network policies for pod-to-pod communication
- ✅ RBAC (Role-Based Access Control)
- ✅ Pod Security Policies
- ✅ Secrets management with AWS Secrets Manager
- ✅ TLS/SSL encryption in transit
- ✅ KMS encryption for RDS
- ✅ Container image scanning with Trivy
- ✅ IAM roles for service accounts (IRSA)
- ✅ VPC security groups
- ✅ API rate limiting

## 📚 Documentation

- [Production Deployment Guide](./PRODUCTION_DEPLOYMENT.md) - Complete production setup
- [Terraform Documentation](./terraform/README.md) - Infrastructure as Code
- [Monitoring Setup](./MONITORING_SETUP.md) - Observability stack
- [GitHub Actions Setup](./.github/WORKFLOWS_SETUP.md) - CI/CD pipelines
- [Architecture Decisions](./docs/ARCHITECTURE.md) - Design rationale

## 🛠️ Development

### Backend Development

```bash
cd backend
npm install
npm run dev    # Start with hot reload
npm test       # Run tests
npm run lint   # ESLint
```

### Frontend Development

```bash
# Edit files in frontend/ directory
# Live in browser at http://localhost:3000
```

### Building Docker Images

```bash
# Backend
docker build -f backend/Dockerfile -t student-portal-backend:latest ./backend

# Frontend
docker build -f frontend/Dockerfile -t student-portal-frontend:latest ./frontend
```

## 📈 Performance Optimization

### Current Optimizations
- Multi-replica deployments with load balancing
- Horizontal Pod Autoscaler (HPA)
- Resource limits and requests
- Connection pooling for database
- CDN ready (CloudFront integration)
- Layer caching in Docker builds

### Scaling Strategy

```bash
# Manual scaling
kubectl scale deployment student-portal-backend \
  -n student-portal \
  --replicas=5

# Check HPA status
kubectl get hpa -n student-portal
```

## 🐛 Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**
   ```bash
   kubectl describe pod <pod-name> -n student-portal
   kubectl logs <pod-name> -n student-portal
   ```

2. **Database Connection Error**
   ```bash
   # Check RDS security groups
   aws ec2 describe-security-groups --group-ids <RDS-SG>
   
   # Test connectivity
   kubectl run mysql-test --image=mysql:8.0 -it --rm \
     -- mysql -h<RDS-ENDPOINT> -u admin -p
   ```

3. **Ingress Not Working**
   ```bash
   kubectl get ingress -n student-portal
   kubectl describe ingress -n student-portal
   kubectl logs -n ingress-nginx deployment/nginx-ingress
   ```

See [Troubleshooting Guide](./PRODUCTION_DEPLOYMENT.md#troubleshooting) for more solutions.

## 💰 Cost Estimation

### Monthly Costs (Approximate - US East 2)

| Component | Quantity | Cost |
|-----------|----------|------|
| EKS Cluster | 1 | $73 |
| EC2 Instances (t3.medium) | 3 | $90 |
| RDS MySQL (db.t3.small) | 1 | $40 |
| Data Transfer | 100GB | $9 |
| Load Balancer | 1 | $20 |
| **Total** | | **~$232/month** |

*Prices vary by region and usage. For accurate estimates, use AWS Pricing Calculator.*

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Workflow

1. Make changes in feature branch
2. Run tests: `npm test`
3. Lint code: `npm run lint`
4. Create PR with description
5. CI/CD runs automatically
6. Wait for approval and merge
7. Deployment happens automatically

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 📞 Support

For issues, questions, or suggestions:

1. Check [Troubleshooting Guide](./PRODUCTION_DEPLOYMENT.md#troubleshooting)
2. Open a [GitHub Issue](../../issues)
3. Contact the DevOps team

## 🔗 Useful Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Last Updated**: March 30, 2026  
**Status**: Production Ready ✅  
**Maintained By**: DevOps Team

```bash
# Login to MySQL
mysql -u root -p

# Create database
CREATE DATABASE student_app;
USE student_app;
```

**Run the schema:**

```sql
-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  role ENUM('student', 'teacher', 'admin') DEFAULT 'student',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username),
  INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert demo users
-- Password for 'student': password123
INSERT INTO users (username, email, password, first_name, last_name, role) 
VALUES (
  'student',
  'student@example.com',
  '$2a$12$ZP5fbwDHKWWTc7Ozlrqe2OjlHsoyCsMDGA6PST/b8Tkl1/oeiDJqC',
  'John',
  'Doe',
  'student'
);

-- Password for 'admin': admin123
INSERT INTO users (username, email, password, first_name, last_name, role) 
VALUES (
  'admin',
  'admin@example.com',
  '$2a$12$iZ2z.lywI.UnbpOQrgfPMeUagbd4Z80JjHpogqR3aVLfPsfgB6Znq',
  'Admin',
  'User',
  'admin'
);
```

### 3. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create .env file
cp .env.example .env

# Edit .env with your MySQL credentials
nano .env
```

**Configure `.env` file:**

```env
PORT=5000
NODE_ENV=development

# MySQL Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=student_app

# JWT Secret (change this!)
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_EXPIRE=7d

# CORS
FRONTEND_URL=http://localhost:3000
```

**Start the backend:**

```bash
npm start
```

You should see:
```
✅ MySQL connected successfully
🚀 Server running on port 5000
📱 Environment: development
🗄️  Database: MySQL
```

### 4. Frontend Setup

```bash
# Open a new terminal
cd frontend

# Serve the frontend (choose one method)

# Method 1: Using live-server (recommended)
npx live-server --port=3000

# Method 2: Using Python
python -m http.server 3000

# Method 3: Using PHP
php -S localhost:3000

# Method 4: Using Node.js http-server
npx http-server -p 3000
```

### 5. Access the Application

Open your browser and navigate to:

**Frontend:** http://localhost:3000  
**Backend API:** http://localhost:5000

## 👥 Demo Credentials

### Student Account
- **Username:** `student`
- **Password:** `password123`

### Admin Account
- **Username:** `admin`
- **Password:** `admin123`

## 📁 Project Structure

```
student-portal/
├── backend/
│   ├── server.js                 # Main server file
│   ├── package.json              # Backend dependencies
│   ├── .env                      # Environment variables
│   ├── config/
│   │   └── database.js           # MySQL connection pool
│   ├── models/
│   │   └── User.js               # User model
│   ├── controllers/
│   │   ├── authController.js     # Authentication logic
│   │   └── userController.js     # User CRUD operations
│   ├── routes/
│   │   ├── authRoutes.js         # Auth routes
│   │   └── userRoutes.js         # User routes
│   ├── middleware/
│   │   ├── auth.js               # JWT verification
│   │   └── errorHandler.js       # Error handling
│   └── utils/
│       └── validators.js         # Input validation
│
├── frontend/
│   ├── index.html                # Login page
│   ├── dashboard.html            # Dashboard page
│   ├── register.html             # Registration page (optional)
│   └── assets/
│       ├── css/
│       └── js/
│
├── database/
│   └── schema.sql                # Database schema
│
├── k8s/                          # Kubernetes configs
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
│
├── Dockerfile                    # Docker configuration
├── docker-compose.yml            # Docker Compose setup
├── .gitignore
└── README.md
```

## 🔌 API Endpoints

### Authentication

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/auth/register` | Register new user | No |
| POST | `/api/auth/login` | Login user | No |
| GET | `/api/auth/me` | Get current user | Yes |
| POST | `/api/auth/logout` | Logout user | Yes |

### Users

| Method | Endpoint | Description | Auth Required | Admin Only |
|--------|----------|-------------|---------------|------------|
| GET | `/api/users` | Get all users | Yes | Yes |
| GET | `/api/users/:id` | Get user by ID | Yes | No |
| PUT | `/api/users/:id` | Update user | Yes | No |
| DELETE | `/api/users/:id` | Delete user | Yes | Yes |

### Example API Requests

**Register:**
```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser",
    "email": "newuser@example.com",
    "password": "password123",
    "firstName": "New",
    "lastName": "User"
  }'
```

**Login:**
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "student",
    "password": "password123"
  }'
```

**Get Current User:**
```bash
curl http://localhost:5000/api/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🐳 Docker Deployment

### Using Docker Compose

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: student-app-mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: student_app
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

  backend:
    build: ./backend
    container_name: student-app-backend
    ports:
      - "5000:5000"
    environment:
      DB_HOST: mysql
      DB_USER: root
      DB_PASSWORD: rootpassword
      DB_NAME: student_app
    depends_on:
      - mysql

  frontend:
    image: nginx:alpine
    container_name: student-app-frontend
    ports:
      - "3000:80"
    volumes:
      - ./frontend:/usr/share/nginx/html

volumes:
  mysql_data:
```

## ☸️ Kubernetes Deployment

### Prerequisites
- kubectl installed and configured
- Access to a Kubernetes cluster
- Docker image pushed to registry

### Deploy to Kubernetes

```bash
# Create namespace
kubectl create namespace student-app

# Apply configurations
kubectl apply -f k8s/deployment.yaml -n student-app
kubectl apply -f k8s/service.yaml -n student-app
kubectl apply -f k8s/ingress.yaml -n student-app

# Check status
kubectl get pods -n student-app
kubectl get services -n student-app

# View logs
kubectl logs -f deployment/nodejs-app-deployment -n student-app
```

### Scale the Application

```bash
# Scale to 5 replicas
kubectl scale deployment nodejs-app-deployment --replicas=5 -n student-app

# Check scaling
kubectl get pods -n student-app
```

## 🛠️ Development

### Running in Development Mode

**Backend with auto-reload:**
```bash
cd backend
npm install -g nodemon
npm run dev
```

**Frontend with live reload:**
```bash
cd frontend
npx live-server --port=3000
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Backend server port | 5000 |
| `NODE_ENV` | Environment (development/production) | development |
| `DB_HOST` | MySQL host | localhost |
| `DB_PORT` | MySQL port | 3306 |
| `DB_USER` | MySQL username | root |
| `DB_PASSWORD` | MySQL password | - |
| `DB_NAME` | Database name | student_app |
| `JWT_SECRET` | JWT signing secret | - |
| `JWT_EXPIRE` | JWT expiration time | 7d |
| `FRONTEND_URL` | Frontend URL for CORS | http://localhost:3000 |

## 🧪 Testing

### Test API Endpoints

```bash
# Health check
curl http://localhost:5000

# Test login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"student","password":"password123"}'
```

### Test Database Connection

```bash
# Login to MySQL
mysql -u root -p

# Check database
USE student_app;
SHOW TABLES;
SELECT * FROM users;
```

## 🔒 Security Features

- ✅ Password hashing with bcrypt (12 rounds)
- ✅ JWT token-based authentication
- ✅ HTTP security headers with Helmet.js
- ✅ CORS protection
- ✅ Input validation and sanitization
- ✅ SQL injection prevention (parameterized queries)
- ✅ XSS protection
- ✅ Rate limiting (can be added)

## 📊 Database Schema

### Users Table

```sql
users
├── id              INT (Primary Key, Auto Increment)
├── username        VARCHAR(50) (Unique, Not Null)
├── email           VARCHAR(100) (Unique, Not Null)
├── password        VARCHAR(255) (Not Null, Hashed)
├── first_name      VARCHAR(50)
├── last_name       VARCHAR(50)
├── role            ENUM('student', 'teacher', 'admin')
├── is_active       BOOLEAN
├── created_at      TIMESTAMP
└── updated_at      TIMESTAMP
```

## 🐛 Troubleshooting

### Common Issues

**1. Backend won't start:**
```bash
# Check if MySQL is running
mysql -u root -p

# Check environment variables
cat backend/.env

# Check MySQL credentials
mysql -u root -p student_app
```

**2. Connection refused error:**
```bash
# Make sure backend is running
cd backend
npm start

# Check port availability
netstat -an | grep 5000
```

**3. CORS errors:**
- Ensure `FRONTEND_URL` in `.env` matches your frontend URL
- Check browser console for specific CORS error

**4. Database connection error:**
- Verify MySQL is running
- Check credentials in `.env`
- Ensure database exists: `CREATE DATABASE student_app;`

**5. JWT token invalid:**
- Ensure `JWT_SECRET` is set in `.env`
- Check token expiration time
- Try logging in again

## 🚀 Production Deployment

### Pre-deployment Checklist

- [ ] Change `JWT_SECRET` to a strong random string
- [ ] Update `NODE_ENV` to `production`
- [ ] Configure production database
- [ ] Enable HTTPS
- [ ] Set up proper CORS origins
- [ ] Configure rate limiting
- [ ] Set up logging and monitoring
- [ ] Enable database backups
- [ ] Configure firewall rules
- [ ] Set up CI/CD pipeline

### Deployment Options

1. **Traditional Server (VPS)**
   - Use PM2 for process management
   - Set up Nginx as reverse proxy
   - Configure SSL with Let's Encrypt

2. **Cloud Platforms**
   - AWS (EC2, RDS, S3)
   - Google Cloud Platform
   - Microsoft Azure
   - DigitalOcean

3. **Container Platforms**
   - Docker + Docker Compose
   - Kubernetes (EKS, GKE, AKS)
   - OpenShift

4. **Serverless**
   - Backend: AWS Lambda, Google Cloud Functions
   - Frontend: Vercel, Netlify
   - Database: AWS RDS, Google Cloud SQL

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Your Name**
- GitHub: [@yourusername](https://github.com/yourusername)
- Email: your.email@example.com

## 🙏 Acknowledgments

- Express.js for the backend framework
- MySQL for the database
- JWT for authentication
- bcrypt.js for password hashing
- All open-source contributors

## 📞 Support

For support, email support@example.com or open an issue on GitHub.

## 🗺️ Roadmap

- [ ] Email verification
- [ ] Password reset functionality
- [ ] Two-factor authentication (2FA)
- [ ] File upload for profile pictures
- [ ] Advanced search and filtering
- [ ] Real-time notifications
- [ ] Chat functionality
- [ ] Mobile application
- [ ] Analytics dashboard
- [ ] API documentation with Swagger

## 📚 Additional Resources

- [Express.js Documentation](https://expressjs.com/)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [JWT Introduction](https://jwt.io/introduction)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
- [REST API Best Practices](https://restfulapi.net/)

---

**Made with ❤️ by Your Name**

*Last updated: November 2025*
