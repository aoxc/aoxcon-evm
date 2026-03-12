const { config } = require('../config');

const GEMINI_ENDPOINT =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

function heuristicAnalyze({ prompt, context }, provider = 'fallback-local') {
  const lowered = `${prompt} ${context || ''}`.toLowerCase();
  const highRiskWords = [
    'delegatecall',
    'drain',
    'exploit',
    'malicious',
    'bypass',
    'reentrancy',
  ];
  const found = highRiskWords.filter((word) => lowered.includes(word));
  const risk = Math.min(100, 20 + found.length * 15);

  return {
    risk,
    action: risk >= 70 ? 'REJECT' : risk >= 40 ? 'REVIEW' : 'APPROVE',
    reason: found.length
      ? `Potential threat markers detected: ${found.join(', ')}`
      : 'No critical threat markers detected in heuristic pass.',
    provider,
  };
}

function parseGeminiText(payload) {
  const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) return null;

  try {
    const parsed = JSON.parse(text);
    if (
      typeof parsed.risk === 'number' &&
      ['APPROVE', 'REVIEW', 'REJECT'].includes(parsed.action) &&
      typeof parsed.reason === 'string'
    ) {
      return {
        risk: Math.max(0, Math.min(100, Math.round(parsed.risk))),
        action: parsed.action,
        reason: parsed.reason,
        provider: 'gemini-1.5-flash',
      };
    }
  } catch (_) {
    return null;
  }

  return null;
}

async function analyzeWithGemini({ prompt, context }) {
  if (!config.geminiApiKey) {
    return heuristicAnalyze({ prompt, context });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4000);

  try {
    const requestPrompt = [
      'Analyze the operation and return STRICT JSON: {"risk":0-100,"action":"APPROVE|REVIEW|REJECT","reason":"..."}.',
      `prompt: ${prompt}`,
      `context: ${context || ''}`,
    ].join('\n');

    const response = await fetch(
      `${GEMINI_ENDPOINT}?key=${config.geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: requestPrompt }] }],
        }),
        signal: controller.signal,
      }
    );

    if (!response.ok) {
      return heuristicAnalyze({ prompt, context }, 'fallback-after-non-200');
    }

    const payload = await response.json();
    const parsed = parseGeminiText(payload);
    if (!parsed) {
      return heuristicAnalyze(
        { prompt, context },
        'fallback-after-parse-failure'
      );
    }

    return parsed;
  } catch (_) {
    return heuristicAnalyze(
      { prompt, context },
      'fallback-after-network-error'
    );
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = { analyzeWithGemini };
