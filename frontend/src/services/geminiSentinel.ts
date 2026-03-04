export class GeminiSentinel {
  private backendUrl = "http://localhost:5000/api/v1/sentinel/analyze";

  constructor(apiKey?: string) {
    if (apiKey) {
      console.log("[Sentinel] Local Neural Key detected.");
    }
  }

  async analyzeSystemState(contextLogs: any, operation: string) {
    try {
      const processedContext = typeof contextLogs === 'object' ? JSON.stringify(contextLogs) : contextLogs;
      
      const response = await fetch(this.backendUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: `Analyze this X Layer tx: ${operation}`,
          context: processedContext
        })
      });

      if (!response.ok) throw new Error("Backend_Unreachable");

      return await response.json();
    } catch (e) {
      return { 
        risk: 100, 
        reason: "Neural Link Blocked: Secure Proxy Offline.", 
        action: "REJECT" 
      };
    }
  }

  async getGeminiResponse(prompt: string, context: any = "Direct Call") {
    return await this.analyzeSystemState(context, prompt);
  }
}

const defaultSentinel = new GeminiSentinel();

export const getGeminiResponse = async (prompt: string, context: any = "") => {
  return await defaultSentinel.getGeminiResponse(prompt, context);
};
