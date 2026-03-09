const { config } = require('../config');

function auth(req, res, next) {
  if (!config.authToken) return next();

  const token = req.header('x-sentinel-token');
  if (token !== config.authToken) {
    return res.status(401).json({ error: 'UNAUTHORIZED' });
  }

  next();
}

module.exports = { auth };
