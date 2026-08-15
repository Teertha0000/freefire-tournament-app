import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
dotenv.config();

export const requireAuth = (req: any, res: any, next: any) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'Missing Authorization header' });

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.SUPABASE_JWT_SECRET || 'fallback_secret');
        req.user = decoded; // { sub: user_id, phone, role }
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
};

// Middleware to check Admin privileges
export const requireAdmin = (req: any, res: any, next: any) => {
    const adminKey = req.headers['x-admin-key'];
    if (adminKey !== process.env.ADMIN_API_KEY) {
        return res.status(401).json({ error: 'Unauthorized Admin Access' });
    }
    next();
};
