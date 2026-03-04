import { 
    getBlockNumber, 
    getGasPrice, 
    simulateTransaction, 
    getBalance, 
    getLogs,
    getAoxcBalance 
} from './xlayer'; 
import { isAddress } from 'viem';
import { getGeminiResponse } from './geminiSentinel';
import { ethers } from 'ethers';

export interface AIAnalysisResult {
    verdict: 'VERIFIED' | 'WARNING' | 'REJECTED';
    riskScore: number; 
    details: string;
    simulatedGas: string;
    aiCommentary?: string;
    timestamp: number;
}

export const analyzeTransaction = async (tx: { 
    to: string; 
    data: string; 
    value?: string 
}): Promise<AIAnalysisResult> => {
    
    if (!isAddress(tx.to)) {
        return { 
            verdict: 'REJECTED', 
            riskScore: 100, 
            details: "INVALID_TARGET_ADDRESS", 
            simulatedGas: '0', 
            timestamp: Date.now() 
        };
    }

    const simulation: any = await simulateTransaction(
        tx.to, 
        tx.data, 
        BigInt(tx.value || '0')
    ).catch(() => ({ success: false, error: "SIMULATION_CRASH", gasEstimate: "0" }));

    if (!simulation.success) {
        return {
            verdict: 'REJECTED',
            riskScore: 100,
            details: `PROTOCOL_REVERT: ${simulation.error}`,
            simulatedGas: '0',
            timestamp: Date.now()
        };
    }

    const gasUsed = BigInt(simulation.gasEstimate || '0');
    
    const aiContext = {
        target: tx.to,
        method_id: tx.data.slice(0, 10),
        gas_estimate: gasUsed.toString(),
        value: tx.value || '0'
    };

    const securityPrompt = `
        As a Web3 Security Auditor, analyze this X Layer tx:
        Target: ${aiContext.target}
        Sighash: ${aiContext.method_id}
        Value: ${aiContext.value}
        
        Strictly return JSON:
        {"risk_score": 0-100, "threats": ["list"], "is_honeypot": boolean}
    `;

    let aiAnalysisRaw = "";
    try {
        aiAnalysisRaw = await getGeminiResponse(securityPrompt, JSON.stringify(aiContext));
    } catch (e) {
        aiAnalysisRaw = "AI_OFFLINE_FALLBACK_RISK_DETECTED";
    }

    let riskScore = 0;

    if (gasUsed > 800000n) riskScore += 30;
    if (tx.to === ethers.ZeroAddress) riskScore += 100;

    const criticalThreats = ["drain", "transferall", "delegatecall", "ownership", "approve", "permit"];
    const foundThreats = criticalThreats.filter(word => 
        typeof aiAnalysisRaw === 'string' && aiAnalysisRaw.toLowerCase().includes(word)
    );
    riskScore += (foundThreats.length * 20);

    if (/danger|malicious|unsafe|exploit/i.test(String(aiAnalysisRaw))) {
        riskScore += 50;
    }

    const score = Math.min(riskScore, 100);
    let finalVerdict: AIAnalysisResult['verdict'] = 'VERIFIED';
    
    if (score >= 85) finalVerdict = 'REJECTED';
    else if (score >= 45) finalVerdict = 'WARNING';

    return {
        verdict: finalVerdict,
        riskScore: score,
        details: score < 45 ? "AOXC Neural Guard: Güvenli." : `Risk tespit edildi: ${foundThreats.join(', ')}`,
        simulatedGas: gasUsed.toString(),
        aiCommentary: typeof aiAnalysisRaw === 'string' ? aiAnalysisRaw : JSON.stringify(aiAnalysisRaw),
        timestamp: Date.now()
    };
};
