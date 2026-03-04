import React, { useMemo, useEffect, useState } from 'react';
import { useAoxcStore } from '../store/useAoxcStore';
import { cn } from '../lib/utils';
import { motion } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import { 
  LayoutDashboard, Wallet, ShieldCheck, Download,
  AlertCircle, FileText, Network, Users, BarChart3,
  GitBranch, Brain, ChevronLeft, ChevronRight, Fingerprint
} from 'lucide-react';

/**
 * @title AOXC Neural Navigation Sidebar v2.5 (Production Ready)
 * @notice Integrated with RightPanel trigger for real-time notification stream.
 */
export const Sidebar = () => {
  const { 
    activeView, setActiveView, pendingTransactions, 
    permissionLevel, setPermissionLevel, notifications,
    isSidebarCollapsed, toggleSidebar,
    setIsRightPanelOpen // Kritik Bağlantı: Sağ paneli açar
  } = useAoxcStore();
  
  const { t } = useTranslation();
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  const menuItems = useMemo(() => [
    { id: 'dashboard', label: t('sidebar.ledger') || 'Main Ledger', icon: LayoutDashboard, color: "primary" },
    { id: 'aoxcan', label: 'AOXCAN CORE', icon: Brain, highlight: true, color: "primary" },
    { id: 'finance', label: t('sidebar.finance') || 'Finance', icon: Wallet, color: "blue" },
    { id: 'analytics', label: t('sidebar.analytics') || 'Neural Analytics', icon: BarChart3, color: "blue" },
    { id: 'skeleton', label: 'System Skeleton', icon: GitBranch, color: "purple" },
    { id: 'sentinel', label: t('sidebar.signatures') || 'Signature Ledger', icon: ShieldCheck, color: "purple" },
    { 
      id: 'notifications', 
      label: 'NOTIFICATIONS', 
      icon: AlertCircle, 
      color: "orange", 
      count: notifications.filter(n => n.type === 'error').length,
      isPanelTrigger: true // Bu öğe sağ paneli kontrol eder
    },
    { id: 'pending', label: t('sidebar.pending') || 'Pending', icon: FileText, color: "primary", count: pendingTransactions.length },
    { id: 'registry', label: t('sidebar.registry') || 'Registry Map', icon: Network, color: "pink" },
    { id: 'governance', label: t('sidebar.governance') || 'War Room', icon: Users, color: "pink" },
  ], [notifications, pendingTransactions, t]);

  const handleNavClick = (id: string, isPanelTrigger?: boolean) => {
    setActiveView(id as any);
    if (isPanelTrigger) {
      setIsRightPanelOpen(true);
    } else {
      setIsRightPanelOpen(false); // Diğer sayfalarda sağ paneli kapatır
    }
  };

  const sidebarWidth = isMobile ? "100%" : (isSidebarCollapsed ? 84 : 280);

  return (
    <motion.div 
      initial={false}
      animate={{ width: sidebarWidth }}
      className="h-full border-r border-white/5 flex flex-col bg-[#050505]/95 backdrop-blur-3xl relative z-[100] transition-all duration-500"
    >
      {/* COMMANDER TOGGLE */}
      <button 
        onClick={toggleSidebar}
        className="absolute -right-3 top-8 w-6 h-10 bg-primary rounded-lg hidden md:flex items-center justify-center text-black hover:bg-primary-hover transition-all shadow-[0_0_20px_var(--color-primary-glow)] z-50"
      >
        {isSidebarCollapsed ? <ChevronRight size={14} strokeWidth={3} /> : <ChevronLeft size={14} strokeWidth={3} />}
      </button>

      <div className="p-5 flex-1 overflow-y-auto scrollbar-hide flex flex-col gap-6">
        {/* LOGO AREA */}
        <div className={cn("flex items-center px-3 mb-4 transition-all", isSidebarCollapsed && !isMobile ? "justify-center" : "justify-between")}>
          {(!isSidebarCollapsed || isMobile) ? (
            <div className="flex flex-col">
               <span className="text-[10px] font-black text-white uppercase tracking-[0.4em]">Command Hub</span>
               <span className="text-[8px] font-mono text-primary/50 mt-1 italic uppercase tracking-widest">v2.5_Stable</span>
            </div>
          ) : (
            <Fingerprint size={18} className="text-primary animate-pulse" />
          )}
        </div>

        {/* NAV LIST */}
        <nav className="space-y-1.5">
          {menuItems.map((item) => (
            <SidebarItem 
              key={item.id}
              item={item}
              isActive={activeView === item.id}
              isCollapsed={isSidebarCollapsed && !isMobile}
              onClick={() => handleNavClick(item.id, item.isPanelTrigger)}
            />
          ))}
        </nav>
      </div>

      {/* FOOTER: RBAC */}
      <div className="mt-auto p-5 space-y-4 border-t border-white/5 bg-black/40 text-[10px]">
        <div className={cn("bg-white/[0.02] rounded-2xl border border-white/5 p-4", isSidebarCollapsed && !isMobile ? "p-2" : "space-y-3")}>
          {!isSidebarCollapsed && (
            <div className="flex items-center justify-between px-1">
               <span className="text-[8px] font-black text-white/30 uppercase tracking-[0.2em]">Access_Level</span>
               <div className="w-1 h-1 rounded-full bg-primary animate-pulse" />
            </div>
          )}
          
          <div className={cn("flex gap-1.5", isSidebarCollapsed && !isMobile ? "flex-col" : "flex-row")}>
            {[0, 1, 2].map((level) => (
              <button
                key={level}
                onClick={() => setPermissionLevel(level)}
                className={cn(
                  "flex items-center justify-center rounded-xl transition-all duration-300 font-black flex-1 py-2.5",
                  permissionLevel === level 
                    ? "bg-primary text-black shadow-[0_0_15px_var(--color-primary-glow)]" 
                    : "bg-white/5 text-white/20 hover:bg-white/10"
                )}
              >
                {level === 0 ? 'G' : level === 1 ? 'O' : 'A'}{!isSidebarCollapsed && (level === 0 ? 'ST' : level === 1 ? 'PR' : 'DM')}
              </button>
            ))}
          </div>
        </div>
      </div>
    </motion.div>
  );
};

// --- Atomic Item Component ---
const SidebarItem = ({ item, isActive, isCollapsed, onClick }: any) => {
  const colorMap: any = {
    primary: "text-primary", blue: "text-blue-500", pink: "text-pink-500",
    purple: "text-purple-500", orange: "text-orange-500"
  };

  const bgMap: any = {
    primary: "bg-primary/10", blue: "bg-blue-500/10", pink: "bg-pink-500/10",
    purple: "bg-purple-500/10", orange: "bg-orange-500/10"
  };

  return (
    <button
      onClick={onClick}
      className={cn(
        "w-full flex items-center relative transition-all duration-300 rounded-2xl py-3.5 px-4 group",
        isActive ? cn(bgMap[item.color], "shadow-inner") : "hover:bg-white/[0.03]",
        isCollapsed ? "justify-center" : "justify-start"
      )}
    >
      {isActive && (
        <motion.div 
          layoutId="sidebarActiveLine"
          className="absolute left-0 w-1 h-6 rounded-r-full bg-primary" 
        />
      )}

      <item.icon 
        size={20} 
        className={cn(
          "shrink-0 transition-all duration-300",
          isActive ? colorMap[item.color] : "text-white/20 group-hover:text-white/60",
          item.highlight && !isActive && "text-primary animate-pulse"
        )} 
      />

      {!isCollapsed && (
        <span className={cn(
          "ml-4 text-[10px] font-black uppercase tracking-widest truncate",
          isActive ? "text-white" : "text-white/40 group-hover:text-white/70"
        )}>
          {typeof item.label === 'string' ? item.label : 'N/A'}
        </span>
      )}

      {item.count ? (
        <div className={cn(
          "absolute flex items-center justify-center font-black transition-all",
          isCollapsed 
            ? "top-2 right-2 w-2 h-2 rounded-full bg-rose-500 animate-ping" 
            : "right-4 px-2 py-0.5 rounded-lg bg-primary text-black text-[9px]"
        )}>
          {!isCollapsed && item.count}
        </div>
      ) : null}
    </button>
  );
};
