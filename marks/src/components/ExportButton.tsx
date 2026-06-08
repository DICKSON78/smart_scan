import React, { useState } from 'react';

interface ExportButtonProps {
  onExport: (format: 'csv' | 'xlsx') => void;
  canExport: boolean;
}

export const ExportButton: React.FC<ExportButtonProps> = ({ onExport, canExport }) => {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="relative inline-block text-left">
      <div>
        <button
          type="button"
          onClick={() => setIsOpen(!isOpen)}
          disabled={!canExport}
          className="inline-flex justify-center w-full rounded-xl border border-transparent shadow-sm px-6 py-3 bg-blue-900 text-base font-bold text-white hover:bg-blue-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-900 disabled:bg-blue-300 disabled:cursor-not-allowed transition-all"
          id="export-menu-button"
          aria-expanded={isOpen}
          aria-haspopup="true"
        >
          Export Data
          <svg className="-mr-1 ml-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
          </svg>
        </button>
      </div>

      {isOpen && (
        <div
          className="origin-bottom-right absolute right-0 bottom-full mb-2 w-56 rounded-xl shadow-2xl bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-50"
          role="menu"
          aria-orientation="vertical"
          aria-labelledby="export-menu-button"
        >
          <div className="py-1" role="none">
            <button
              onClick={() => {
                onExport('csv');
                setIsOpen(false);
              }}
              className="text-gray-700 dark:text-gray-200 block w-full text-left px-4 py-3 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors font-medium"
              role="menuitem"
            >
              Export as CSV (.csv)
            </button>
            <button
              onClick={() => {
                onExport('xlsx');
                setIsOpen(false);
              }}
              className="text-gray-700 dark:text-gray-200 block w-full text-left px-4 py-3 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors font-medium"
              role="menuitem"
            >
              Export as Excel (.xlsx)
            </button>
          </div>
        </div>
      )}
      
      {isOpen && (
        <div 
          className="fixed inset-0 z-40" 
          onClick={() => setIsOpen(false)}
        ></div>
      )}
    </div>
  );
};
