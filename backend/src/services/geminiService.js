const { config } = require('../config');

async function analyzeWithGemini({ prompt, context }) {
  // Controlled fallback for development and environments without AI credentials.
  if (!config.geminiApiKey) {
    return {
      risk: 35,
      action: 'REVIEW',
      reason: 'Gemini API key not configured; deterministic fallback analysis applied.',
      provider: 'fallback-local'
    };
  }

  // Placeholder integration boundary (can be replaced with @google/generative-ai call).
  const lowered = `${prompt} ${context}`.toLowerCase();
  const highRiskWords = ['delegatecall', 'drain', 'exploit', 'malicious'];
  const found = highRiskWords.filter((w) => lowered.includes(w));

  const risk = Math.min(100, 20 + found.length * 20);

  return {
    risk,
    action: risk >= 70 ? 'REJECT' : risk >= 40 ? 'REVIEW' : 'APPROVE',
    reason: found.length
      ? `Potential threat markers detected: ${found.join(', ')}`
      : 'No critical threat markers detected in heuristic pass.',
    provider: 'gemini-bridge-stub'
  };
}

module.exports = { analyzeWithGemini };
