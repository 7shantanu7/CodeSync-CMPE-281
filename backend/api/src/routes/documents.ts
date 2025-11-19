import express, { Response } from 'express';
import { body, validationResult } from 'express-validator';
import { v4 as uuidv4 } from 'uuid';
import { pool } from '../config/database';
import { authenticate, AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';
import { S3 } from 'aws-sdk';

const router = express.Router();
const s3 = new S3({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET_NAME = process.env.S3_BUCKET || '';

// All routes require authentication
router.use(authenticate);

// Create document
router.post('/',
  body('title').isLength({ min: 1, max: 255 }).trim(),
  async (req: AuthRequest, res: Response, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { title } = req.body;
      const userId = req.user!.id;

      const result = await pool.query(
        'INSERT INTO documents (title, owner_id) VALUES ($1, $2) RETURNING *',
        [title, userId]
      );

      const document = result.rows[0];

      // Store initial snapshot in S3
      if (BUCKET_NAME) {
        await s3.putObject({
          Bucket: BUCKET_NAME,
          Key: `documents/${document.id}/snapshot-${Date.now()}.json`,
          Body: JSON.stringify({ content: '', version: 0 }),
          ContentType: 'application/json',
        }).promise();
      }

      res.status(201).json({
        message: 'Document created',
        document,
      });
    } catch (error) {
      next(error);
    }
  }
);

// List user documents
router.get('/', async (req: AuthRequest, res: Response, next) => {
  try {
    const userId = req.user!.id;

    const result = await pool.query(
      `SELECT d.*, u.username as owner_username 
       FROM documents d
       JOIN users u ON d.owner_id = u.id
       WHERE d.owner_id = $1 
       OR d.id IN (
         SELECT document_id FROM document_permissions WHERE user_id = $1
       )
       ORDER BY d.updated_at DESC`,
      [userId]
    );

    res.json({ documents: result.rows });
  } catch (error) {
    next(error);
  }
});

// Get document by ID
router.get('/:id', async (req: AuthRequest, res: Response, next) => {
  try {
    const { id } = req.params;
    const userId = req.user!.id;

    const result = await pool.query(
      `SELECT d.*, u.username as owner_username 
       FROM documents d
       JOIN users u ON d.owner_id = u.id
       WHERE d.id = $1 AND (
         d.owner_id = $2 OR 
         d.id IN (SELECT document_id FROM document_permissions WHERE user_id = $2)
       )`,
      [id, userId]
    );

    if (result.rows.length === 0) {
      throw new AppError('Document not found', 404);
    }

    res.json({ document: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Update document
router.put('/:id',
  body('title').optional().isLength({ min: 1, max: 255 }).trim(),
  body('content').optional().isString(),
  async (req: AuthRequest, res: Response, next) => {
    try {
      const { id } = req.params;
      const userId = req.user!.id;
      const { title, content } = req.body;

      // Check permission
      const permCheck = await pool.query(
        'SELECT * FROM documents WHERE id = $1 AND owner_id = $2',
        [id, userId]
      );

      if (permCheck.rows.length === 0) {
        throw new AppError('Unauthorized', 403);
      }

      const updates: string[] = [];
      const values: any[] = [];
      let paramCount = 1;

      if (title !== undefined) {
        updates.push(`title = $${paramCount++}`);
        values.push(title);
      }

      if (content !== undefined) {
        updates.push(`content = $${paramCount++}`);
        values.push(content);
      }

      updates.push(`updated_at = CURRENT_TIMESTAMP`);
      values.push(id);

      const query = `UPDATE documents SET ${updates.join(', ')} WHERE id = $${paramCount} RETURNING *`;
      const result = await pool.query(query, values);

      res.json({
        message: 'Document updated',
        document: result.rows[0],
      });
    } catch (error) {
      next(error);
    }
  }
);

// Delete document
router.delete('/:id', async (req: AuthRequest, res: Response, next) => {
  try {
    const { id } = req.params;
    const userId = req.user!.id;

    const result = await pool.query(
      'DELETE FROM documents WHERE id = $1 AND owner_id = $2 RETURNING *',
      [id, userId]
    );

    if (result.rows.length === 0) {
      throw new AppError('Document not found or unauthorized', 404);
    }

    res.json({ message: 'Document deleted' });
  } catch (error) {
    next(error);
  }
});

// Share document
router.post('/:id/share',
  body('userEmail').isEmail().normalizeEmail(),
  body('permission').isIn(['read', 'write']),
  async (req: AuthRequest, res: Response, next) => {
    try {
      const { id } = req.params;
      const { userEmail, permission } = req.body;
      const ownerId = req.user!.id;

      // Verify ownership
      const docCheck = await pool.query(
        'SELECT * FROM documents WHERE id = $1 AND owner_id = $2',
        [id, ownerId]
      );

      if (docCheck.rows.length === 0) {
        throw new AppError('Unauthorized', 403);
      }

      // Find user to share with
      const userResult = await pool.query(
        'SELECT id FROM users WHERE email = $1',
        [userEmail]
      );

      if (userResult.rows.length === 0) {
        throw new AppError('User not found', 404);
      }

      const shareUserId = userResult.rows[0].id;

      // Add permission
      await pool.query(
        `INSERT INTO document_permissions (document_id, user_id, permission) 
         VALUES ($1, $2, $3) 
         ON CONFLICT (document_id, user_id) 
         DO UPDATE SET permission = $3`,
        [id, shareUserId, permission]
      );

      res.json({ message: 'Document shared successfully' });
    } catch (error) {
      next(error);
    }
  }
);

export default router;

