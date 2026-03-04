import React from 'react';
import { Pulse } from './Pulse';
import { cn } from '../lib/utils';
import { Activity, Zap, Cpu, ShieldCheck } from 'lucide-react';

interface HeaderProps {
  isOnline: boolean;
  latency: number;
}

/**
 * @title AOXC Neural OS - Header Engine v2.0.0 (Precision Edition)
 * @dev Hizalama sorunları giderildi, komponentler belirli slotlara (Left, Center, Right) sabitlendi.
 */
export const Header: React.FC<HeaderProps> = ({ isOnline, latency }) => {
  const SYSTEM_VERSION = "v2.0.0_RC1";

  return (
    <header className="h-16 shrink-0 z-[60] relative bg-[#050505] border-b border-white/5 flex items-center overflow-hidden">
      
      {/* 1. LEFT SLOT: BRAND & VERSION (Fixed Width) */}
      <div className="w-80 px-6 flex items-center gap-4 border-r border-white/5 h-full">
        <div className="flex flex-col">
          <h1 className="text-white font-black text-sm tracking-[0.4em] uppercase leading-none">
            AOXC<span className="text-primary text-glow">OS</span>
          </h1>
          <div className="flex items-center gap-2 mt-1.5">
            <span className="text-[8px] text-white/30 font-mono tracking-widest font-bold uppercase">Core_Module</span>
            <span className="text-[8px] text-primary font-mono font-black">{SYSTEM_VERSION}</span>
          </div>
        </div>
      </div>

      {/* 2. CENTER SLOT: DATA DYNAMICS (Flexible & Centered) */}
      <div className="flex-1 flex items-center justify-center gap-2 px-4 h-full">
        
        {/* $AOXC MAIN TOKEN - Precision Aligned */}
        <div className="flex items-center h-10 bg-primary/5 border border-primary/10 rounded-sm overflow-hidden group">
          <div className="px-3 h-full flex items-center bg-primary/10 border-r border-primary/10">
            <span className="text-[10px] text-primary font-black tracking-tighter">$AOXC</span>
          </div>
          <div className="px-4 flex flex-col justify-center min-w-[100px]">
            <span className="text-[11px] text-white font-black font-mono leading-none tracking-tight">0.038409</span>
            <span className="text-[7px] text-primary/40 font-bold mt-1 uppercase tracking-tighter">Current_Value</span>
          </div>
        </div>

        {/* SEPARATOR GAP */}
        <div className="w-4 h-[1px] bg-white/5" />

        {/* OKB WIDGET - Precision Aligned */}
        <div className="flex items-center h-10 bg-white/[0.02] border border-white/5 rounded-sm overflow-hidden hover:bg-white/[0.04] transition-all">
          <div className="px-3 h-full flex items-center bg-white/5 border-r border-white/5">
            <span className="text-[9px] text-white/40 font-black tracking-tighter uppercase">OKB</span>
          </div>
          <div className="px-4 flex flex-col justify-center min-w-[80px]">
            <span className="text-[10px] text-white/80 font-bold leading-none">42.18</span>
            <span className="text-[7px] text-emerald-500 font-black mt-1 leading-none">+1.24%</span>
          </div>
        </div>
      </div>

      {/* 3. RIGHT SLOT: TELEMETRY & CONNECTION (Fixed Width) */}
      <div className="w-[450px] flex items-center justify-end px-6 gap-8 border-l border-white/5 h-full bg-black/20">
        
        {/* System Telemetry Cluster */}
        <div className="hidden xl:flex items-center gap-6">
          <div className="flex flex-col items-end">
            <span className="text-[7px] text-white/20 uppercase font-black tracking-[0.2em]">Gas_X1</span>
            <div className="flex items-center gap-1.5 mt-0.5">
              <Zap size={10} className="text-primary" />
              <span className="text-[10px] text-white/80 font-mono font-bold">0.1 GWEI</span>
            </div>
          </div>
          <div className="flex flex-col items-end">
            <span className="text-[7px] text-white/20 uppercase font-black tracking-[0.2em]">Sentinel</span>
            <div className="flex items-center gap-1.5 mt-0.5">
              <ShieldCheck size={10} className="text-emerald-500" />
              <span className="text-[10px] text-emerald-500 font-mono font-bold uppercase italic">Secure</span>
            </div>
          </div>
        </div>

        {/* Connection Status */}
        <div className="flex items-center gap-4 pl-6 border-l border-white/5">
          <div className="flex flex-col items-end">
            <div className="flex items-center gap-2">
              <span className={cn(
                "text-[9px] font-black uppercase tracking-widest transition-colors",
                isOnline ? "text-primary" : "text-rose-500"
              )}>
                {isOnline ? 'Uplink_Stable' : 'Uplink_Offline'}
              </span>
              <div className={cn(
                "w-2 h-2 rounded-full shadow-lg",
                isOnline ? "bg-primary animate-pulse shadow-primary/20" : "bg-rose-500 shadow-rose-500/20"
              )} />
            </div>
            <span className="text-[8px] text-white/10 font-mono font-bold mt-1 uppercase tracking-tighter">
              DLY: {latency}MS // FR_NODE_B
            </span>
          </div>
        </div>
      </div>

      {/* BOTTOM FX: Sync Pulse Bar */}
      <div className="absolute bottom-0 left-0 w-full overflow-hidden opacity-40">
        <Pulse isOnline={isOnline} latency={latency} />
      </div>

      {/* AESTHETIC: Top Reflective Edge */}
      <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-white/5 to-transparent" />
    </header>
  );
};
