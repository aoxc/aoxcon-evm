import React from 'react';
import { useAoxcStore } from '../store/useAoxcStore';
import { motion, AnimatePresence } from 'motion/react';
import { AlertCircle, CheckCircle2, Info, XCircle, Trash2, Bell, ShieldAlert } from 'lucide-react';
import { cn } from '../lib/utils';
import { useTranslation } from 'react-i18next';

/**
 * @title AOXC Notification Center
 * @task Sadece sistem bildirimlerini izler, listeler ve temizler.
 */
export const NotificationCenter: React.FC = () => {
  const notifications = useAoxcStore((state) => state.notifications) || [];
  const setNotifications = useAoxcStore((state) => state.setNotifications);
  const { t } = useTranslation();

  const clearNotification = (id: string) => {
    setNotifications(notifications.filter((n) => n.id !== id));
  };

  const clearAll = () => {
    // Güvenlik protokolü: Sadece hatalar (error) saklanır, gerisi temizlenir.
    setNotifications(notifications.filter((n) => n.type === 'error'));
  };

  const icons = {
    info: <Info size={16} className="text-primary" />,
    warning: <AlertCircle size={16} className="text-amber-500" />,
    error: <XCircle size={16} className="text-rose-500" />,
    success: <CheckCircle2 size={16} className="text-emerald-500" />,
  };

  return (
    <div className="flex flex-col h-full w-full bg-[#050505] font-mono relative overflow-hidden border-l border-white/5">
      {/* Visual Layer: Glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-64 h-32 bg-primary/5 blur-[80px] pointer-events-none" />

      {/* Header: Control & Stats */}
      <div className="p-6 flex items-center justify-between relative z-10 border-b border-white/5 bg-black/20">
        <div>
          <h2 className="text-white font-black text-xs uppercase tracking-[0.3em] flex items-center gap-3">
            <Bell size={18} className={cn(notifications.length > 0 && "animate-pulse text-primary")} />
            {t('notifications.title', 'System Alerts')}
          </h2>
          <p className="text-white/20 text-[9px] mt-1 uppercase tracking-widest font-bold">
            Neural_Stream // Handlers: {notifications.length}
          </p>
        </div>
        
        {notifications.length > 0 && (
          <button 
            onClick={clearAll}
            className="px-3 py-1 bg-white/5 hover:bg-rose-500/10 border border-white/10 hover:border-rose-500/20 rounded text-[9px] font-black text-white/40 hover:text-rose-500 transition-all uppercase tracking-widest"
          >
            Flush Buffer
          </button>
        )}
      </div>

      {/* Stream Area: List of Signals */}
      <div className="flex-1 overflow-y-auto p-5 space-y-4 scrollbar-hide relative z-10">
        <AnimatePresence mode="popLayout" initial={false}>
          {notifications.length === 0 ? (
            <motion.div 
              initial={{ opacity: 0, scale: 0.98 }} 
              animate={{ opacity: 1, scale: 1 }}
              className="flex flex-col items-center justify-center h-full text-center space-y-5 opacity-40"
            >
              <div className="w-16 h-16 bg-primary/5 rounded-full flex items-center justify-center border border-primary/10">
                <ShieldAlert size={28} className="text-primary/30" />
              </div>
              <div className="space-y-1">
                <p className="text-[10px] text-white uppercase tracking-[0.2em] font-black">All Systems Nominal</p>
                <p className="text-[9px] text-white/20 uppercase">No threats detected in X Layer</p>
              </div>
            </motion.div>
          ) : (
            notifications.map((n) => (
              <motion.div
                key={n.id}
                layout
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                className={cn(
                  "p-4 rounded-xl border bg-[#0a0a0a]/50 backdrop-blur-md flex items-start gap-4 group transition-all relative",
                  n.type === 'error' ? "border-rose-500/20 shadow-[0_0_20px_rgba(244,63,94,0.05)]" : 
                  n.type === 'warning' ? "border-amber-500/20" : "border-white/5"
                )}
              >
                <div className={cn(
                  "p-2 rounded-lg shrink-0",
                  n.type === 'error' ? "bg-rose-500/10" : 
                  n.type === 'warning' ? "bg-amber-500/10" : "bg-primary/10"
                )}>
                  {icons[n.type as keyof typeof icons] || icons.info}
                </div>
                
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className={cn(
                      "text-[9px] font-black uppercase tracking-widest",
                      n.type === 'error' ? "text-rose-500" : 
                      n.type === 'warning' ? "text-amber-500" : "text-primary"
                    )}>
                      {n.type}_SIGNAL
                    </span>
                    <span className="text-[8px] text-white/10 font-mono">
                      {new Date(n.timestamp).toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                  <p className="text-[11px] text-white/70 leading-relaxed font-medium">
                    {n.message}
                  </p>
                </div>

                <button 
                  onClick={() => clearNotification(n.id)}
                  className="p-1.5 text-white/5 hover:text-rose-500 hover:bg-rose-500/10 rounded-lg transition-all opacity-0 group-hover:opacity-100"
                >
                  <Trash2 size={12} />
                </button>
              </motion.div>
            ))
          )}
        </AnimatePresence>
      </div>

      {/* Footer: Diagnostic */}
      <div className="p-5 border-t border-white/5 flex justify-between items-center bg-black/60 relative z-20">
        <span className="text-[8px] font-black uppercase tracking-[0.3em] text-white/20 italic">Neural Dispatcher</span>
        <div className="flex items-center gap-2">
           <div className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse shadow-[0_0_8px_var(--color-primary)]" />
           <span className="text-[8px] font-mono text-primary uppercase font-bold tracking-tighter">Node_Secure</span>
        </div>
      </div>
    </div>
  );
};
