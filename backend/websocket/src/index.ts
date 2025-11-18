import express from 'express';
import { createServer } from 'http';
import { Server, Socket } from 'socket.io';
import cors from 'cors';
import compression from 'compression';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import Redis from 'ioredis';
import { pool } from './config/database';

dotenv.config();

const app = express();
const httpServer = createServer(app);

// Redis clients
const redisClient = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

const redisPub = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

const redisSub = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

// Socket.IO server
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    credentials: true,
  },
  path: '/socket',
  transports: ['websocket', 'polling'],
});

const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

app.use(cors());
app.use(compression());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    service: 'websocket',
    timestamp: new Date().toISOString(),
    connections: io.engine.clientsCount,
  });
});

// Authentication middleware for Socket.IO
io.use((socket: Socket, next) => {
  try {
    const token = socket.handshake.auth.token || socket.handshake.query.token;
    
    if (!token) {
      return next(new Error('Authentication error'));
    }

    const decoded = jwt.verify(token as string, JWT_SECRET) as any;
    (socket as any).user = decoded;
    next();
  } catch (error) {
    next(new Error('Authentication error'));
  }
});

// Document state management
interface DocumentState {
  content: string;
  version: number;
  users: Set<string>;
}

const documents = new Map<string, DocumentState>();

// Socket.IO connection handling
io.on('connection', async (socket: Socket) => {
  const user = (socket as any).user;
  console.log(`User connected: ${user.username} (${socket.id})`);

  // Join document room
  socket.on('join-document', async (data: { documentId: string }) => {
    try {
      const { documentId } = data;

      // Verify user has access to document
      const result = await pool.query(
        `SELECT d.* FROM documents d
         WHERE d.id = $1 AND (
           d.owner_id = $2 OR
           d.id IN (SELECT document_id FROM document_permissions WHERE user_id = $2)
         )`,
        [documentId, user.id]
      );

      if (result.rows.length === 0) {
        socket.emit('error', { message: 'Access denied' });
        return;
      }

      const document = result.rows[0];

      // Join room
      socket.join(documentId);

      // Initialize document state if not exists
      if (!documents.has(documentId)) {
        documents.set(documentId, {
          content: document.content || '',
          version: 0,
          users: new Set(),
        });
      }

      const docState = documents.get(documentId)!;
      docState.users.add(user.username);

      // Store user's current document
      await redisClient.set(`user:${socket.id}:document`, documentId, 'EX', 3600);

      // Add user to presence set
      await redisClient.sadd(`presence:${documentId}`, user.username);
      await redisClient.expire(`presence:${documentId}`, 3600);

      // Send current state to user
      socket.emit('document-state', {
        content: docState.content,
        version: docState.version,
        users: Array.from(docState.users),
      });

      // Notify others
      socket.to(documentId).emit('user-joined', {
        username: user.username,
        userId: user.id,
      });

      console.log(`${user.username} joined document ${documentId}`);
    } catch (error) {
      console.error('Error joining document:', error);
      socket.emit('error', { message: 'Failed to join document' });
    }
  });

  // Handle edit events
  socket.on('edit', async (data: { documentId: string; changes: any; cursor: any }) => {
    try {
      const { documentId, changes, cursor } = data;

      const docState = documents.get(documentId);
      if (!docState) {
        socket.emit('error', { message: 'Document not found' });
        return;
      }

      // Update version
      docState.version++;

      // Apply changes to content (simplified - in production use OT or CRDT)
      if (changes.content !== undefined) {
        docState.content = changes.content;
      }

      // Broadcast to other users in the document
      socket.to(documentId).emit('edit', {
        userId: user.id,
        username: user.username,
        changes,
        cursor,
        version: docState.version,
      });

      // Publish to Redis for other instances
      await redisPub.publish(`document:${documentId}:edits`, JSON.stringify({
        userId: user.id,
        username: user.username,
        changes,
        cursor,
        version: docState.version,
        socketId: socket.id,
      }));

      // Store in operational transform cache
      await redisClient.lpush(
        `ot:${documentId}`,
        JSON.stringify({ changes, version: docState.version, timestamp: Date.now() })
      );
      await redisClient.ltrim(`ot:${documentId}`, 0, 99); // Keep last 100 ops

    } catch (error) {
      console.error('Error handling edit:', error);
    }
  });

  // Handle cursor movement
  socket.on('cursor', async (data: { documentId: string; position: any }) => {
    try {
      const { documentId, position } = data;

      socket.to(documentId).emit('cursor', {
        userId: user.id,
        username: user.username,
        position,
      });
    } catch (error) {
      console.error('Error handling cursor:', error);
    }
  });

  // Leave document
  socket.on('leave-document', async (data: { documentId: string }) => {
    try {
      const { documentId } = data;

      socket.leave(documentId);

      const docState = documents.get(documentId);
      if (docState) {
        docState.users.delete(user.username);

        if (docState.users.size === 0) {
          // Save final state to database
          await pool.query(
            'UPDATE documents SET content = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
            [docState.content, documentId]
          );
          documents.delete(documentId);
        }
      }

      await redisClient.srem(`presence:${documentId}`, user.username);
      await redisClient.del(`user:${socket.id}:document`);

      socket.to(documentId).emit('user-left', {
        username: user.username,
        userId: user.id,
      });

      console.log(`${user.username} left document ${documentId}`);
    } catch (error) {
      console.error('Error leaving document:', error);
    }
  });

  // Handle disconnect
  socket.on('disconnect', async () => {
    try {
      const documentId = await redisClient.get(`user:${socket.id}:document`);

      if (documentId) {
        const docState = documents.get(documentId);
        if (docState) {
          docState.users.delete(user.username);

          if (docState.users.size === 0) {
            await pool.query(
              'UPDATE documents SET content = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
              [docState.content, documentId]
            );
            documents.delete(documentId);
          }
        }

        await redisClient.srem(`presence:${documentId}`, user.username);
        await redisClient.del(`user:${socket.id}:document`);

        socket.to(documentId).emit('user-left', {
          username: user.username,
          userId: user.id,
        });
      }

      console.log(`User disconnected: ${user.username} (${socket.id})`);
    } catch (error) {
      console.error('Error handling disconnect:', error);
    }
  });
});

// Subscribe to Redis for cross-instance communication
redisSub.subscribe('document:*:edits');
redisSub.on('message', (channel, message) => {
  try {
    const data = JSON.parse(message);
    const documentId = channel.split(':')[1];

    // Broadcast to all sockets except the sender
    io.to(documentId).except(data.socketId).emit('edit', {
      userId: data.userId,
      username: data.username,
      changes: data.changes,
      cursor: data.cursor,
      version: data.version,
    });
  } catch (error) {
    console.error('Error handling Redis message:', error);
  }
});

// Graceful shutdown
const gracefulShutdown = async () => {
  console.log('Shutting down WebSocket service...');

  // Save all document states
  for (const [documentId, docState] of documents.entries()) {
    try {
      await pool.query(
        'UPDATE documents SET content = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
        [docState.content, documentId]
      );
    } catch (error) {
      console.error(`Error saving document ${documentId}:`, error);
    }
  }

  await pool.end();
  await redisClient.quit();
  await redisPub.quit();
  await redisSub.quit();

  httpServer.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

httpServer.listen(PORT, () => {
  console.log(`WebSocket service listening on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

