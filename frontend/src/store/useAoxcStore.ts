import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';
import { ethers } from 'ethers';
import { getProvider, getSecureContract, ChainId } from '../services/xlayer';
import { GeminiSentinel } from '../services/geminiSentinel';

/**
 * @title AOXC Neural OS State Controller (Hardened Edition)
 * @notice Centralized state management with Autonomous Sentinel Verification.
 */

// --- TYPES & INTERFACES ---

export type StatusColor = 'green' | 'yellow' | 'orange' | 'red' | 'blue';

export interface Log {
    id: string;
    message: string;
    type: 'info' | 'error' | 'success' | 'warning' | 'ai';
    timestamp: number;
}

export interface Notification {
    id: string;
    message: string;
    type: 'info' | 'error' | 'success' | 'warning';
    timestamp: number;
}

export interface LedgerEntry {
    id: string;
    txHash: string;
    module: string;
    operation: string;
    status: 'success' | 'warning' | 'error' | 'PROVISIONAL';
    timestamp: number;
    aiVerification?: string;
}

export interface PendingTx {
    id: string;
    operation: string;
    module: string;
    details?: any;
    requiredSignatures: number;
    currentSignatures: number;
    params?: any[];
}

interface AoxcState {
    blockNumber: number;
    epochTime: number;
    networkStatus: 'healthy' | 'warning' | 'critical';
    networkLoad: string;
    gasEfficiency: number;
    isProcessing: boolean;
    permissionLevel: number;
    logs: Log[];
    notifications: Notification[];
    pendingTransactions: PendingTx[];
    ledgerEntries: LedgerEntry[];
    analyticsData: any[];
    chatMessages: Array<{ id: string; content: string; role: 'user' | 'ai'; timestamp: number }>;
    activeView: string;
    activeNotary: any | null;
    upgradeAvailable: boolean;
    isMobileMenuOpen: boolean;
    isRightPanelOpen: boolean;
    isSidebarCollapsed: boolean;
    repairState: 'stable' | 'syncing' | 'idle';
    repairTarget: string | null;
    statusMatrix: {
        core: StatusColor;
        access: StatusColor;
        finance: StatusColor;
        infra: StatusColor;
        gov: StatusColor;
    };
    syncNetwork: () => Promise<void>;
    addLog: (message: string, type?: Log['type']) => void;
    addNotification: (message: string, type: Notification['type']) => void;
    setNotifications: (updater: (prev: Notification[]) => Notification[]) => void;
    addLedgerEntry: (entry: Partial<LedgerEntry>) => void;
    addPendingTx: (tx: Partial<PendingTx>) => void;
    approvePendingTx: (id: string) => Promise<void>;
    incrementBlock: () => void;
    setPermissionLevel: (level: number) => void;
    setActiveView: (view: string) => void;
    setActiveNotary: (notary: any) => void;
    toggleMobileMenu: () => void;
    toggleRightPanel: () => void;
    toggleSidebar: () => void;
    triggerRepair: (target: string) => void;
    dismissUpgrade: () => void;
    addChatMessage: (content: string, role: 'user' | 'ai') => void;
}

const REGISTRY_ADDRESS = import.meta.env.VITE_AOXC_REGISTRY_ADDR || "0x71C7656EC7ab88b098defB751B7401B5f6d8976F";

export const useAoxcStore = create<AoxcState>()(
    subscribeWithSelector((set, get) => ({
        blockNumber: 0,
        epochTime: Math.floor(Date.now() / 1000),
        networkStatus: 'healthy',
        networkLoad: '0 gwei',
        gasEfficiency: 98,
        isProcessing: false,
        permissionLevel: 1,
        logs: [],
        notifications: [],
        pendingTransactions: [],
        ledgerEntries: [],
        analyticsData: [],
        chatMessages: [],
        activeView: 'dashboard',
        activeNotary: null,
        upgradeAvailable: true,
        isMobileMenuOpen: false,
        isRightPanelOpen: true,
        isSidebarCollapsed: false,
        repairState: 'stable',
        repairTarget: null,
        statusMatrix: {
            core: 'green',
            access: 'green',
            finance: 'green',
            infra: 'green',
            gov: 'green'
        },

        syncNetwork: async () => {
            try {
                const provider = getProvider(ChainId.MAINNET);
                const [block, feeData] = await Promise.all([
                    provider.getBlockNumber(),
                    provider.getFeeData()
                ]);

                const registryAbi = ["function paused() view returns (bool)"];
                const registry = getSecureContract(REGISTRY_ADDRESS, registryAbi, provider);
                const isPaused = await registry.paused().catch(() => false);

                set({
                    blockNumber: block,
                    networkStatus: isPaused ? 'warning' : 'healthy',
                    networkLoad: `${ethers.formatUnits(feeData.gasPrice || 0n, 'gwei').slice(0, 4)} gwei`,
                    epochTime: Math.floor(Date.now() / 1000)
                });
            } catch (error) {
                set({ networkStatus: 'critical' });
            }
        },

        addLog: (message, type = 'info') => {
            const timestamp = Date.now();
            const id = ethers.keccak256(ethers.toUtf8Bytes(message + timestamp)).substring(2, 12);
            set((state) => ({
                logs: [{ id, message, type, timestamp }, ...state.logs].slice(0, 50)
            }));
        },

        addNotification: (message, type) => {
            const id = Math.random().toString(36).substring(7);
            set((state) => ({
                notifications: [{ id, message, type, timestamp: Date.now() }, ...state.notifications]
            }));
        },

        setNotifications: (updater) => set((state) => ({ notifications: updater(state.notifications) })),

        addLedgerEntry: (entry) => set((state) => ({
            ledgerEntries: [{
                id: Math.random().toString(36).substring(7),
                timestamp: Date.now(),
                txHash: '0x' + Math.random().toString(16).slice(2),
                module: 'Unknown',
                operation: 'Unknown',
                status: 'success',
                ...entry
            } as LedgerEntry, ...state.ledgerEntries]
        })),

        addPendingTx: (tx) => set((state) => ({
            pendingTransactions: [{
                id: Math.random().toString(36).substring(7),
                requiredSignatures: 3,
                currentSignatures: 1,
                ...tx
            } as PendingTx, ...state.pendingTransactions]
        })),

        approvePendingTx: async (id: string) => {
            const tx = get().pendingTransactions.find(t => t.id === id);
            if (!tx || get().isProcessing) return;

            set({ isProcessing: true });
            try {
                const sentinel = new GeminiSentinel(import.meta.env.VITE_GEMINI_API_KEY);
                const context = get().logs.slice(0, 5).map(l => l.message).join("\n");
                const analysis = await sentinel.analyzeSystemState(context, tx.operation);

                if (analysis.risk > 70) {
                    get().addLog(`VETO: Risk Score ${analysis.risk}/100`, "error");
                    set({ isProcessing: false });
                    return;
                }

                await new Promise(r => setTimeout(r, 2000));
                set((state) => ({
                    pendingTransactions: state.pendingTransactions.filter(t => t.id !== id),
                    isProcessing: false
                }));
                get().addLog(`TX_FINALIZED: ${tx.operation}`, "success");
            } catch (error) {
                set({ isProcessing: false });
            }
        },

        incrementBlock: () => set(state => ({ blockNumber: state.blockNumber + 1 })),
        setPermissionLevel: (level) => set({ permissionLevel: level }),
        setActiveView: (view) => set({ activeView: view }),
        setActiveNotary: (notary) => set({ activeNotary: notary }),
        toggleMobileMenu: () => set(state => ({ isMobileMenuOpen: !state.isMobileMenuOpen })),
        toggleRightPanel: () => set(state => ({ isRightPanelOpen: !state.isRightPanelOpen })),
        toggleSidebar: () => set(state => ({ isSidebarCollapsed: !state.isSidebarCollapsed })),
        dismissUpgrade: () => set({ upgradeAvailable: false }),
        triggerRepair: (target) => {
            set({ repairState: 'syncing', repairTarget: target });
            setTimeout(() => set({ repairState: 'stable', repairTarget: null }), 3000);
        },
        addChatMessage: (content, role) => {
            const id = Math.random().toString(36).substring(7);
            set(state => ({
                chatMessages: [...state.chatMessages, { id, content, role, timestamp: Date.now() }]
            }));
        }
    }))
);
