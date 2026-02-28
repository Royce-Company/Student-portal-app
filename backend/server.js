// backend/server.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const errorHandler = require('./middleware/errorHandler');
const db = require('./config/database');

const app = express();

// CORS configuration - MUST be before other middleware
app.use(cors({
  origin: ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://3.142.194.173:3000',  'http://3.142.194.173:5000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Other middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/', (req, res) => {
  res.json({
    message: '🚀 Student App API with MySQL',
    version: '1.0.0',
    database: 'MySQL',
    endpoints: {
      auth: '/api/auth',
      users: '/api/users'
    }
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);

// Error handling
app.use(errorHandler);

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📱 Environment: ${process.env.NODE_ENV}`);
  console.log(`🗄️  Database: MySQL`);
});

// Temporary password hash generator (remove after testing)
app.get('/test/hash/:password', async (req, res) => {
  const bcrypt = require('bcryptjs');
  const hash = await bcrypt.hash(req.params.password, 12);
  res.json({ password: req.params.password, hash: hash });
});