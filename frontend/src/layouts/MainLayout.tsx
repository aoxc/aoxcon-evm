import React from 'react';
import { cn } from '../lib/utils';
import { Header } from '../components/Header';
import { Footer } from '../components/Footer';
import { Sidebar } from '../components/Sidebar';
import { StatusMatrix } from '../components/StatusMatrix';
import { motion, AnimatePresence } from 'framer-motion';

interface MainLayoutProps {
  children: React.ReactNode;
  isOnline: boolean;
  latency: number;
  isMobileMenuOpen: boolean;
  toggleMobileMenu: () => void;
  isRightPanelOpen: boolean;
  rightPanelContent: React.ReactNode;
}

/**
 * @title AOXC Neural OS - Layout Architect (Final v2.5)
 * @notice Panel çakışmaları ve layout kaymaları giderilmiş tam sürüm.
 */
export const MainLayout: React.FC<MainLayoutProps> = ({ 
  children, 
  isOnline, 
  latency, 
  isMobileMenuOpen, 
  toggleMobileMenu, 
  isRightPanelOpen, 
  rightPanelContent 
}) => {
  return (
    <div className="h-screen w-full bg-[#030303] text-white flex flex-col font-mono overflow-hidden relative selection:bg-primary/30">
      
      {/* 1. HEADER (Top Fixed Height) */}
      <Header isOnline={isOnline} latency={latency} />

      {/* BODY WRAPPER */}
      <div className="flex-1 flex overflow-hidden relative">
        
        {/* 2. SIDEBAR - Responsive Logic */}
        <aside className={cn(
          "fixed inset-y-0 left-0 z-[60] md:relative md:flex transition-all duration-500 ease-[cubic-bezier(0.23,1,0.32,1)]",
          isMobileMenuOpen ? "translate-x-0 w-72" : "-translate-x-full md:translate-x-0 w-72 lg:w-80"
        )}>
          <Sidebar />
        </aside>

        {/* MOBILE OVERLAY (Sidebar arkası, içerik önü) */}
        <AnimatePresence>
          {isMobileMenuOpen && (
            <motion.div 
              initial={{ opacity: 0 }} 
              animate={{ opacity: 1 }} 
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/80 z-[55] md:hidden backdrop-blur-md" 
              onClick={toggleMobileMenu} 
            />
          )}
        </AnimatePresence>

        {/* 3. CENTRAL COMMAND (Ana Çalışma Alanı) */}
        <main className="flex-1 flex flex-col min-w-0 bg-[#060606] relative border-x border-white/5 overflow-hidden">
          
          {/* Status Matrix Sub-Header */}
          <StatusMatrix />
          
          <div className="flex-1 flex overflow-hidden relative">
            {/* Viewport: Scrollable Area */}
            <section className="flex-1 flex flex-col min-w-0 overflow-y-auto scrollbar-hide relative">
               <div className="flex-1 p-0">
                  {children}
               </div>
            </section>

            {/* 4. RIGHT SIDE PANEL (Neural Notifications) */}
            <AnimatePresence mode="wait">
              {isRightPanelOpen && (
                <motion.aside 
                  initial={{ x: 400, opacity: 0 }} 
                  animate={{ x: 0, opacity: 1 }} 
                  exit={{ x: 400, opacity: 0 }}
                  transition={{ type: "spring", damping: 30, stiffness: 200 }}
                  className={cn(
                    // Mobil ve Tablet: Üstten binen panel
                    "fixed inset-y-0 right-0 z-[70] w-full sm:w-96 bg-[#080808]/98 backdrop-blur-3xl border-l border-white/10",
                    // Desktop (xl): İçeriği itmeyen, yanına kolon olarak yerleşen yapı
                    "xl:relative xl:z-20 xl:flex xl:flex-col xl:bg-[#080808]/50 shadow-[-20px_0_40px_rgba(0,0,0,0.5)]"
                  )}
                >
                  <div className="h-full w-full flex flex-col overflow-hidden shadow-2xl">
                    {rightPanelContent}
                  </div>
                </motion.aside>
              )}
            </AnimatePresence>
          </div>

          {/* 5. FOOTER (System Diagnostic) */}
          <Footer />
        </main>
      </div>

      {/* GLOBAL UI FX: Scanning Line */}
      <div className="absolute top-0 left-0 w-full h-[1px] bg-primary/10 scanline pointer-events-none z-[100]" />
    </div>
  );
};
