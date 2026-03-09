import { Contract, JsonRpcProvider, formatUnits } from 'ethers';

const CORE_ABI = [
  'function totalSupply() view returns (uint256)',
  'function getMintPolicy() view returns (uint256 yearlyLimit, uint256 mintedInCurrentYear, uint256 windowStart)',
  'function getAiStatus() view returns (bool isActive, uint256 currentNeuralThreshold)',
  'function isNeuralProtectEnabled(address account) view returns (bool)',
  'function isCriticalAddress(address account) view returns (bool)'
];

export interface NeuralDashboardState {
  totalSupply: string;
  yearlyLimit: string;
  mintedInCurrentYear: string;
  windowStart: number;
  aiActive: boolean;
  neuralThreshold: string;
  neuralProtectEnabled: boolean;
  criticalAddress: boolean;
}

export class AoxcConnector {
  private provider: JsonRpcProvider;
  private core: Contract;

  constructor(rpcUrl: string, coreAddress: string) {
    this.provider = new JsonRpcProvider(rpcUrl);
    this.core = new Contract(coreAddress, CORE_ABI, this.provider);
  }

  async fetchDashboardState(account: string): Promise<NeuralDashboardState> {
    const [supply, mintPolicy, aiStatus, protect, critical] = await Promise.all([
      this.core.totalSupply(),
      this.core.getMintPolicy(),
      this.core.getAiStatus(),
      this.core.isNeuralProtectEnabled(account),
      this.core.isCriticalAddress(account)
    ]);

    return {
      totalSupply: formatUnits(supply, 18),
      yearlyLimit: formatUnits(mintPolicy.yearlyLimit ?? mintPolicy[0], 18),
      mintedInCurrentYear: formatUnits(mintPolicy.mintedInCurrentYear ?? mintPolicy[1], 18),
      windowStart: Number(mintPolicy.windowStart ?? mintPolicy[2]),
      aiActive: Boolean(aiStatus.isActive ?? aiStatus[0]),
      neuralThreshold: String(aiStatus.currentNeuralThreshold ?? aiStatus[1]),
      neuralProtectEnabled: Boolean(protect),
      criticalAddress: Boolean(critical)
    };
  }
}
