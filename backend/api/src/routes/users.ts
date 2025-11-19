import express, { Response } from 'express';
import { pool } from '../config/database';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = express.Router();

// All routes require authentication
router.use(authenticate);

// Get current user profile
router.get('/me', async (req: AuthRequest, res: Response, next) => {
  try {
    const userId = req.user!.id;

    const result = await pool.query(
      'SELECT id, email, username, created_at FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Search users by email or username
router.get('/search', async (req: AuthRequest, res: Response, next) => {
  try {
    const { q } = req.query;

    if (!q || typeof q !== 'string') {
      return res.status(400).json({ error: 'Query parameter required' });
    }

    const result = await pool.query(
      `SELECT id, email, username FROM users 
       WHERE email ILIKE $1 OR username ILIKE $1 
       LIMIT 10`,
      [`%${q}%`]
    );

    res.json({ users: result.rows });
  } catch (error) {
    next(error);
  }
});

export default router;

