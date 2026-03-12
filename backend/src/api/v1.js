const express = require('express');
const { analyze } = require('../controllers/sentinelController');
const { validateAnalyzePayload } = require('../middleware/validator');
const { auth } = require('../middleware/auth');

const router = express.Router();

router.get('/health', (req, res) => {
  res
    .status(200)
    .json({ status: 'ok', service: 'sentinel-api', version: 'v1' });
});

router.post('/sentinel/analyze', auth, validateAnalyzePayload, analyze);

module.exports = { v1Router: router };
