import { ethers, JsonRpcProvider, Contract, type InterfaceAbi } from 'ethers';

const NETWORKS = {
  [196]: {
    name: "X-Layer Mainnet",
    rpc: "https://rpc.xlayer.tech",
    aoxc: "0xeb9580c3946bb47d73aae1d4f7a94148b554b2f4" 
  },
  [195]: {
    name: "X-Layer Testnet",
    rpc: "https://testrpc.xlayer.tech",
    aoxc: "0xYourTestnetTokenAddress" 
  }
};

export enum ChainId {
  MAINNET = 196, 
  XLAYER_MAINNET = 196,
  XLAYER_TESTNET = 195
}

export interface NeuralBalance {
  okb: string;  
  aoxc: string; 
}

export const ERC20_ABI: InterfaceAbi = [
  "function balanceOf(address) view returns (uint256)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)"
];

let currentProvider: JsonRpcProvider | null = null;
let currentChain: number = ChainId.XLAYER_MAINNET;

export const getProvider = (chainId: number = currentChain): JsonRpcProvider => {
  const config = NETWORKS[chainId as keyof typeof NETWORKS] || NETWORKS[196];
  if (!currentProvider || currentChain !== chainId) {
    currentProvider = new JsonRpcProvider(config.rpc);
    currentChain = chainId;
  }
  return currentProvider;
};

export const throttleRequest = async <T>(fn: () => Promise<T>): Promise<T> => await fn();

export const getSecureContract = (address: string, abi: InterfaceAbi, connection?: any) => {
  const provider = typeof connection === 'number' ? getProvider(connection) : (connection || getProvider());
  return new Contract(address, abi, provider);
};

export const getNeuralBalances = async (address: string, chainId: number = currentChain): Promise<NeuralBalance> => {
  if (!ethers.isAddress(address)) return { okb: "0.00", aoxc: "0.00" };

  try {
    const provider = getProvider(chainId);
    const [nativeBalance, tokenBalance] = await Promise.all([
      provider.getBalance(address),
      getAoxcBalance(address, chainId)
    ]);

    return {
      okb: ethers.formatEther(nativeBalance),
      aoxc: tokenBalance || "0.00"
    };
  } catch (error) {
    return { okb: "0.00", aoxc: "0.00" };
  }
};

export const getAoxcBalance = async (address: string, chainId: number = currentChain): Promise<string | null> => {
  const config = NETWORKS[chainId as keyof typeof NETWORKS];
  if (!config || !config.aoxc) return "0.00";

  return await throttleRequest(async () => {
    try {
      const contract = new Contract(config.aoxc, ERC20_ABI, getProvider(chainId));
      const balance = await contract.balanceOf(address);
      return ethers.formatUnits(balance, 18);
    } catch (e) {
      return null;
    }
  });
};

export const simulateTransaction = async (to: string, data: string, value: bigint, chainId: number = currentChain) => {
  return await throttleRequest(async () => {
    try {
      const provider = getProvider(chainId);
      const [gasEstimate] = await Promise.all([
        provider.estimateGas({ to, data, value }),
        provider.call({ to, data, value })
      ]);

      return { 
        success: true, 
        gasEstimate: gasEstimate.toString(), 
        risk: "CLEAN", 
        timestamp: Date.now() 
      };
    } catch (error: any) {
      let errorMsg = error.reason || (error.message?.includes("insufficient funds") ? "Yetersiz OKB Bakiyesi" : "Simülasyon Hatası");
      return { success: false, error: errorMsg, risk: "HIGH", timestamp: Date.now(), gasEstimate: "0" };
    }
  });
};

export const getBlockNumber = async () => (await getProvider()).getBlockNumber();
export const getGasPrice = async () => (await getProvider()).getFeeData();
export const debugTrace = async (txHash: string) => await getProvider().send("debug_traceTransaction", [txHash, {}]);
export const getBalance = async (address: string) => ethers.formatEther(await (await getProvider()).getBalance(address));
export const getLogs = async (filter: any) => (await getProvider()).getLogs(filter);
