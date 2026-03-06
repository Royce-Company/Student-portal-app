const db = require('../config/database');
const bcrypt = require('bcryptjs');

class User {
  // Find user by username or email
  static async findByUsernameOrEmail(identifier) {
    const [rows] = await db.query(
      'SELECT * FROM users WHERE username = ? OR email = ?',
      [identifier, identifier]
    );
    return rows[0];
  }

  // Find user by ID
  static async findById(id) {
    const [rows] = await db.query(
      'SELECT id, username, email, first_name, last_name, role, is_active, created_at FROM users WHERE id = ?',
      [id]
    );
    return rows[0];
  }

  // Find all users
  static async findAll() {
    const [rows] = await db.query(
      'SELECT id, username, email, first_name, last_name, role, is_active, created_at FROM users'
    );
    return rows;
  }

  // Create new user
  static async create(userData) {
    const { username, email, password, firstName, lastName, role = 'student' } = userData;

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    const [result] = await db.query(
      'INSERT INTO users (username, email, password, first_name, last_name, role) VALUES (?, ?, ?, ?, ?, ?)',
      [username, email, hashedPassword, firstName, lastName, role]
    );

    return this.findById(result.insertId);
  }

  // Update user
  static async update(id, userData) {
    const { firstName, lastName, email } = userData;
    
    await db.query(
      'UPDATE users SET first_name = ?, last_name = ?, email = ? WHERE id = ?',
      [firstName, lastName, email, id]
    );

    return this.findById(id);
  }

  // Delete user
  static async delete(id) {
    const [result] = await db.query('DELETE FROM users WHERE id = ?', [id]);
    return result.affectedRows > 0;
  }

  // Compare password
  static async comparePassword(plainPassword, hashedPassword) {
    return await bcrypt.compare(plainPassword, hashedPassword);
  }

  // Check if username exists
  static async usernameExists(username) {
    const [rows] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    return rows.length > 0;
  }

  // Check if email exists
  static async emailExists(email) {
    const [rows] = await db.query('SELECT id FROM users WHERE email = ?', [email]);
    return rows.length > 0;
  }
}

module.exports = User;