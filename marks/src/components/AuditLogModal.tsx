import React from 'react';
import { AuditEntry } from '../types';
import { CloseIcon, ListIcon } from './Icons';
import { motion, AnimatePresence } from 'motion/react';

interface AuditLogModalProps {
  isOpen: boolean;
  onClose: () => void;
  logs: AuditEntry[];
}

export const AuditLogModal: React.FC<AuditLogModalProps> = ({ isOpen, onClose, logs }) => {
  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
          />
          <motion.div 
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            className="relative bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-2xl max-h-[80vh] flex flex-col overflow-hidden"
          >
            <div className="p-6 border-b border-gray-100 dark:border-gray-700 flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                  <ListIcon className="w-6 h-6 text-blue-900 dark:text-blue-400" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-gray-900 dark:text-white">Security Audit Trail</h2>
                  <p className="text-xs text-gray-500">Immutable record of all data modifications</p>
                </div>
              </div>
              <button 
                onClick={onClose}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
              >
                <CloseIcon className="w-6 h-6" />
              </button>
            </div>

            <div className="flex-grow overflow-y-auto p-6">
              {logs.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-500">No activity recorded yet.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {[...logs].reverse().map((entry) => (
                    <div 
                      key={entry.id} 
                      className="flex gap-4 p-3 rounded-xl border border-gray-100 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900/20"
                    >
                      <div className="flex-shrink-0 pt-1">
                        <div className={`w-2 h-2 rounded-full mt-1.5 ${
                          entry.action === 'EXTRACT' ? 'bg-green-500' :
                          entry.action === 'EDIT' ? 'bg-orange-500' :
                          entry.action === 'DELETE' ? 'bg-red-500' : 'bg-blue-500'
                        }`} />
                      </div>
                      <div className="flex-grow">
                        <div className="flex justify-between items-start mb-1">
                          <span className="text-xs font-bold uppercase tracking-wider text-gray-400">
                            {entry.action}
                          </span>
                          <span className="text-[10px] text-gray-400 font-mono">
                            {new Date(entry.timestamp).toLocaleString()}
                          </span>
                        </div>
                        <p className="text-sm text-gray-700 dark:text-gray-300">
                          {entry.details}
                        </p>
                        {(entry.oldValue !== undefined || entry.newValue !== undefined) && (
                          <div className="mt-2 flex items-center gap-2 text-[10px] font-mono">
                            <span className="text-red-400 line-through">{String(entry.oldValue ?? 'null')}</span>
                            <span className="text-gray-400">→</span>
                            <span className="text-green-400 font-bold">{String(entry.newValue ?? 'null')}</span>
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="p-4 bg-gray-50 dark:bg-gray-800/50 border-t border-gray-100 dark:border-gray-700 text-center">
              <p className="text-[10px] text-gray-400">
                This log ensures data integrity and prevents unauthorized marks manipulation.
              </p>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
