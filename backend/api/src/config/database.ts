import { Pool } from 'pg';

export const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'codesync',
  user: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test connection
pool.on('connect', () => {
  console.log('Database connected');
});

pool.on('error', (err) => {
  console.error('Unexpected database error:', err);
});

// Initialize database schema
export const initializeDatabase = async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        username VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS documents (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title VARCHAR(255) NOT NULL,
        content TEXT DEFAULT '',
        owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS document_permissions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        permission VARCHAR(50) DEFAULT 'read',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(document_id, user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_id);
      CREATE INDEX IF NOT EXISTS idx_permissions_document ON document_permissions(document_id);
      CREATE INDEX IF NOT EXISTS idx_permissions_user ON document_permissions(user_id);
    `);
    console.log('Database schema initialized');
  } catch (error) {
    console.error('Error initializing database:', error);
  }
};

// Call initialization
initializeDatabase();

