const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const crypto = require('crypto');

const { config } = require('./config');
const { logger, withRequestContext } = require('./utils/logger');
const { v1Router } = require('./api/v1');

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  const requestId = req.header('x-request-id') || crypto.randomUUID();
  req.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  const log = withRequestContext(requestId);
  const start = Date.now();

  log.info({
    event: 'api.request',
    message: 'Incoming request.',
    method: req.method,
    path: req.originalUrl
  });

  res.on('finish', () => {
    log.info({
      event: 'api.response',
      message: 'Request completed.',
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - start
    });
  });

  next();
});

app.use('/api/v1', v1Router);

app.use((req, res) => {
  res.status(404).json({ error: 'NOT_FOUND' });
});

app.use((err, req, res, _next) => {
  const log = withRequestContext(req.requestId || 'n/a');
  log.error({ event: 'service.error', message: 'Unhandled error.', error: err.message });
  res.status(500).json({ error: 'INTERNAL_SERVER_ERROR' });
});

app.listen(config.port, () => {
  logger.info({
    event: 'service.health',
    message: 'Sentinel backend started.',
    port: config.port,
    env: config.env
  });
});
