const { analyzeWithGemini } = require('../services/geminiService');
const { withRequestContext } = require('../utils/logger');

async function analyze(req, res) {
  const requestId = req.requestId;
  const log = withRequestContext(requestId);

  try {
    const { prompt, context } = req.validated;

    log.info({
      event: 'sentinel.analysis',
      message: 'Analysis request accepted.',
    });
    const result = await analyzeWithGemini({ prompt, context });

    log.info({
      event: 'sentinel.analysis',
      message: 'Analysis completed.',
      risk: result.risk,
      action: result.action,
      provider: result.provider,
    });

    return res.status(200).json(result);
  } catch (error) {
    log.error({
      event: 'service.error',
      message: 'Sentinel analysis failed.',
      error: error.message,
    });

    return res.status(500).json({
      error: 'ANALYSIS_FAILED',
      reason: 'Internal sentinel processing error.',
    });
  }
}

module.exports = { analyze };
