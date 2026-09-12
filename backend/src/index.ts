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
import { challengeRoutes } from './routes/challenges';
import { supabaseAdmin } from './supabaseClient';

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
app.use('/challenges', challengeRoutes);

// Background Auto-Settlement Engine (Every 30 seconds)
setInterval(async () => {
    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_auto_settle_expired');
        if (data && Number(data) > 0) {
            console.log(`⚡ Auto-settled ${data} expired P2P challenge(s)!`);
        }
    } catch (_) {
        // Silently handle if DB is reconnecting
    }
}, 30000);

app.listen(PORT as number, '0.0.0.0', () => {
    console.log(`🚀 Secure Backend Server running on port ${PORT}`);
});

