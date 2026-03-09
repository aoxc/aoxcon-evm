const { z } = require('zod');

const analyzeSchema = z.object({
  prompt: z.string().min(3),
  context: z.string().optional().default('')
});

function validateAnalyzePayload(req, res, next) {
  const result = analyzeSchema.safeParse(req.body || {});
  if (!result.success) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      details: result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message }))
    });
  }

  req.validated = result.data;
  next();
}

module.exports = { validateAnalyzePayload };
