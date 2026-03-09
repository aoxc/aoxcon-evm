const config = {
  env: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 5000),
  logLevel: process.env.LOG_LEVEL || 'info',
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  authToken: process.env.SENTINEL_AUTH_TOKEN || ''
};

module.exports = { config };
