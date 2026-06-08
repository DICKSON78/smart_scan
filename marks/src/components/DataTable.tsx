import React, { useRef } from 'react';
import { StudentMark } from '../types';
import { TrashIcon, PencilIcon } from './Icons';
import { Mic, Image as ImageIcon, Keyboard } from 'lucide-react';

interface DataTableProps {
  marks: StudentMark[];
  setMarks: (marks: StudentMark[]) => void;
  maxMark: number;
}

export const DataTable: React.FC<DataTableProps> = ({ marks, setMarks, maxMark }) => {
  const inputRefs = useRef<{ [key: string]: HTMLInputElement | null }>({});

  const handleUpdateMark = (id: string, field: keyof StudentMark, value: string) => {
    setMarks(marks.map(m => {
      if (m.id === id) {
        if (field === 'mark') {
          const numValue = parseFloat(value);
          const finalMark = (isNaN(numValue) || numValue < 0 || numValue > maxMark) ? null : numValue;
          return { ...m, [field]: finalMark };
        }
        return { ...m, [field]: value };
      }
      return m;
    }));
  };

  const handleDeleteRow = (id: string) => {
    setMarks(marks.filter(m => m.id !== id));
  };

  const handleFocusRow = (id: string) => {
    inputRefs.current[id]?.focus();
  };

  return (
    <div className="overflow-x-auto rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800/50">
          <tr>
            <th scope="col" className="px-6 py-3 text-left text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Student ID / Name</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Mark (Max: {maxMark})</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Source</th>
            <th scope="col" className="px-6 py-3 text-right text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          {marks.map((mark) => (
            <tr key={mark.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors">
              <td className="px-6 py-4 whitespace-nowrap max-w-[150px] sm:max-w-xs overflow-x-auto custom-scrollbar">
                <input
                  ref={el => inputRefs.current[mark.id] = el}
                  type="text"
                  value={mark.studentId}
                  onChange={(e) => handleUpdateMark(mark.id, 'studentId', e.target.value)}
                  className="min-w-[200px] w-full bg-transparent border-b border-transparent hover:border-gray-300 dark:hover:border-gray-600 focus:border-blue-900 focus:outline-none px-1 py-1 text-sm font-medium text-gray-900 dark:text-white"
                  placeholder="ID or Name"
                />
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <input
                  type="number"
                  step="0.5"
                  min="0"
                  max={maxMark}
                  value={mark.mark === null ? '' : mark.mark}
                  onChange={(e) => handleUpdateMark(mark.id, 'mark', e.target.value)}
                  className={`w-full bg-transparent border-b border-transparent hover:border-gray-300 dark:hover:border-gray-600 focus:border-blue-900 focus:outline-none px-1 py-1 text-sm font-bold ${
                    mark.mark !== null && mark.mark > maxMark ? 'text-red-500' : 'text-blue-900 dark:text-blue-400'
                  }`}
                />
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                {mark.source === 'voice' ? (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-teal-50 text-teal-700 dark:bg-teal-900/20 dark:text-teal-400">
                    <Mic className="w-3.5 h-3.5" />
                    voice
                  </span>
                ) : mark.source === 'manual' ? (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-gray-100 text-gray-750 dark:bg-gray-700 dark:text-gray-300">
                    <Keyboard className="w-3.5 h-3.5" />
                    manual
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400">
                    <ImageIcon className="w-3.5 h-3.5" />
                    scan
                  </span>
                )}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium flex justify-end gap-1">
                <button
                  onClick={() => handleFocusRow(mark.id)}
                  className="text-gray-400 hover:text-blue-900 dark:hover:text-blue-400 p-2 rounded-full hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-all"
                  aria-label="Edit entry"
                >
                  <PencilIcon className="w-5 h-5" />
                </button>
                <button
                  onClick={() => handleDeleteRow(mark.id)}
                  className="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300 p-2 rounded-full hover:bg-red-50 dark:hover:bg-red-900/20 transition-all"
                  aria-label="Delete entry"
                >
                  <TrashIcon className="w-5 h-5" />
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
