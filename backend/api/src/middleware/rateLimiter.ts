import { Request, Response, NextFunction } from 'express';
import { redisClient } from '../config/redis';

export const rateLimiter = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const key = `rate_limit:${ip}`;
    
    const requests = await redisClient.incr(key);
    
    if (requests === 1) {
      await redisClient.expire(key, 60); // 60 seconds window
    }
    
    if (requests > 100) { // 100 requests per minute
      return res.status(429).json({ 
        error: 'Too many requests, please try again later' 
      });
    }
    
    next();
  } catch (error) {
    // If Redis fails, allow the request
    next();
  }
};

