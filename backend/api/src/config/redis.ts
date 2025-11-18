import Redis from 'ioredis';

export const redisClient = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  maxRetriesPerRequest: 3,
});

redisClient.on('connect', () => {
  console.log('Redis connected');
});

redisClient.on('error', (err) => {
  console.error('Redis error:', err);
});

// Helper functions
export const cacheGet = async (key: string): Promise<any> => {
  const data = await redisClient.get(key);
  return data ? JSON.parse(data) : null;
};

export const cacheSet = async (key: string, value: any, expirySeconds: number = 3600): Promise<void> => {
  await redisClient.setex(key, expirySeconds, JSON.stringify(value));
};

export const cacheDelete = async (key: string): Promise<void> => {
  await redisClient.del(key);
};

