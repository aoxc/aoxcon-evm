const { createLogger, format, transports } = require('winston');
const { config } = require('../config');

const logger = createLogger({
  level: config.logLevel,
  defaultMeta: { service: 'aoxcore-sentinel-backend', env: config.env },
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json()
  ),
  transports: [new transports.Console()],
});

function withRequestContext(requestId) {
  return {
    info: (payload) => logger.info({ requestId, ...payload }),
    warn: (payload) => logger.warn({ requestId, ...payload }),
    error: (payload) => logger.error({ requestId, ...payload }),
  };
}

module.exports = { logger, withRequestContext };
