import React from 'react';
import { LogoIcon } from './Icons';

interface HeaderProps {
  sessionName: string;
  onSwitchSession: () => void;
  onViewHistory: () => void;
}

export const Header: React.FC<HeaderProps> = ({ sessionName, onSwitchSession, onViewHistory }) => {
  return (
    <header className="mb-8 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div className="flex items-center space-x-3">
        <div className="bg-blue-900 p-2 rounded-lg shadow-lg">
          <LogoIcon className="w-8 h-8 text-white" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white leading-tight">SmartScan Marks <span className="text-[10px] font-normal opacity-50">v1.3</span></h1>
          <p className="text-sm text-gray-500 dark:text-gray-400">OCR-Powered Mark Extraction</p>
        </div>
      </div>
      
      <div className="flex items-center space-x-4">
        <button 
          onClick={onViewHistory}
          className="flex items-center gap-2 text-xs bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 px-4 py-2 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 transition-all active:scale-95"
        >
          <span className="w-2 h-2 bg-blue-500 rounded-full animate-pulse" />
          <span className="font-bold text-gray-700 dark:text-gray-300">Security Audit</span>
        </button>

        <div className="flex items-center bg-white dark:bg-gray-800 px-4 py-2 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700">
          <div className="mr-4">
            <p className="text-[10px] uppercase tracking-wider text-gray-400 font-bold">Active Session</p>
            <p className="text-sm font-bold text-blue-900 dark:text-blue-400 truncate max-w-[150px]">{sessionName}</p>
          </div>
          <button 
            onClick={onSwitchSession}
            className="text-xs bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 px-3 py-1.5 rounded-lg transition-colors font-semibold"
          >
            Switch
          </button>
        </div>
      </div>
    </header>
  );
};
