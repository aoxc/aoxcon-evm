const { z } = require('zod');

const analyzeSchema = z.object({
  prompt: z.string().min(3).max(4000),
  context: z.string().max(8000).optional().default(''),
});

function validateAnalyzePayload(req, res, next) {
  const result = analyzeSchema.safeParse(req.body || {});
  if (!result.success) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      details: result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      })),
    });
  }

  req.validated = result.data;
  return next();
}

module.exports = { validateAnalyzePayload };
