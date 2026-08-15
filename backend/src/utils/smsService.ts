import axios from 'axios';

/**
 * Generic SMS Service for Bangladesh Local Providers.
 * 
 * Works with most BD providers (e.g., Greenweb, BDBulkSMS, etc.)
 * by making a simple HTTP GET/POST request with the API key and message.
 */
export const sendSMS = async (phone: string, message: string): Promise<boolean> => {
    // 1. Get credentials from environment
    const apiKey = process.env.SMS_API_KEY;
    const apiUrl = process.env.SMS_API_URL;
    const senderId = process.env.SMS_SENDER_ID; // Optional for some providers

    // 2. If SMS API is not configured, just log it (useful for local development)
    if (!apiKey || !apiUrl) {
        console.warn('⚠️ [SMS Simulation] No SMS_API_URL or SMS_API_KEY provided in .env');
        console.log(`💬 [SMS to ${phone}]: ${message}`);
        return true; 
    }

    try {
        // 3. Format the request. 
        // Note: Different providers use different parameter names. 
        // Adjust 'token', 'to', 'message' based on your specific provider's API docs!
        
        // Example format for GreenWeb SMS:
        // http://api.greenweb.com.bd/api.php?token=${apiKey}&to=${phone}&message=${message}
        
        const response = await axios.get(apiUrl, {
            params: {
                token: apiKey,          // Your API Key
                to: phone,              // The recipient's phone number
                message: message,       // The SMS body
                // sender_id: senderId  // Uncomment if your provider requires a Sender ID
            }
        });

        // 4. Check if the API accepted it
        if (response.status === 200 || response.status === 201) {
            console.log(`✅ [SMS Sent] to ${phone} successfully!`);
            return true;
        } else {
            console.error(`❌ [SMS Failed] HTTP Status: ${response.status}`, response.data);
            return false;
        }
    } catch (error: any) {
        console.error(`❌ [SMS Error] Failed to connect to SMS API:`, error.message);
        return false;
    }
};
