# 🎓 Student Portal - Full Stack Application

A modern, full-stack student management system built with Node.js, Express, MySQL, and vanilla JavaScript. Features a beautiful dark-themed UI with JWT authentication, role-based access control, and a RESTful API.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Node](https://img.shields.io/badge/node-%3E%3D14.0.0-brightgreen.svg)


## ✨ Features

### Frontend
- 🎨 Modern dark-themed UI with glassmorphism effects
- 🔐 Secure JWT-based authentication
- 👤 User profile management
- 📊 Interactive dashboard with statistics
- 🎯 Role-based access control (Student, Teacher, Admin)
- 📱 Fully responsive design
- ⚡ Smooth animations and transitions
- 🎭 Beautiful loading states and error handling

### Backend
- 🚀 RESTful API with Express.js
- 🗄️ MySQL database with connection pooling
- 🔒 JWT token authentication
- 🛡️ Password hashing with bcrypt
- ✅ Input validation with express-validator
- 🎯 Role-based authorization middleware
- 📝 Comprehensive error handling
- 🔍 CORS enabled for cross-origin requests

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v14.0.0 or higher) - [Download](https://nodejs.org/)
- **MySQL** (v5.7 or higher) - [Download](https://dev.mysql.com/downloads/)
- **Git** - [Download](https://git-scm.com/)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/student-portal.git
cd student-portal
```

### 2. Database Setup

**Start MySQL and create the database:**

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
