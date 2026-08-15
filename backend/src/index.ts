import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json()); // To parse JSON bodies (needed for Paymently webhooks)

import { webhookRoutes } from './routes/webhooks';
import { adminRoutes } from './routes/admin';
import { matchRoutes } from './routes/matches';
import { financeRoutes } from './routes/finance';
import { userRoutes } from './routes/user';

// Health Check Route
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'OK', message: 'Tournament Backend is running securely.' });
});

// Mount Routes
app.use('/webhooks', webhookRoutes);
app.use('/admin', adminRoutes);
app.use('/match', matchRoutes);
app.use('/finance', financeRoutes);
app.use('/user', userRoutes);

app.listen(PORT as number, '0.0.0.0', () => {
    console.log(`🚀 Secure Backend Server running on port ${PORT}`);
});
