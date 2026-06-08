import React, { useState, useEffect, useMemo } from 'react';
import { StudentMark } from '../types';
import { DataTable } from './DataTable';
import { CloseIcon, LogoIcon } from './Icons';

interface ReviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (reviewedMarks: StudentMark[]) => void;
  marks: StudentMark[];
  maxMark: number;
  existingMarks: StudentMark[];
}

export const ReviewModal: React.FC<ReviewModalProps> = ({ isOpen, onClose, onConfirm, marks, maxMark, existingMarks }) => {
  const [reviewedMarks, setReviewedMarks] = useState<StudentMark[]>(marks);
  
  // Update state when marks change (e.g. when modal is opened with new data)
  useEffect(() => {
    setReviewedMarks(marks);
  }, [marks]);

  const { newUniqueMarks, duplicateCount } = useMemo(() => {
    const existingStudentIds = new Set(existingMarks.map(m => m.studentId));
    const newUniqueMarks = reviewedMarks.filter(m => !existingStudentIds.has(m.studentId));
    const duplicateCount = reviewedMarks.length - newUniqueMarks.length;
    return { newUniqueMarks, duplicateCount };
  }, [reviewedMarks, existingMarks]);


  const [bulkMark, setBulkMark] = useState<string>('');

  const handleBulkApply = () => {
    const markValue = parseFloat(bulkMark);
    if (isNaN(markValue) || markValue < 0 || markValue > maxMark) return;
    setReviewedMarks(prev => prev.map(m => ({ ...m, mark: markValue })));
    setBulkMark('');
  };

  if (!isOpen) return null;

  const handleConfirm = () => {
    onConfirm(newUniqueMarks);
  };

  return (
    <div className="fixed inset-0 bg-gray-900 bg-opacity-75 flex items-center justify-center z-50 p-4" aria-modal="true" role="dialog">
      <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex justify-between items-center p-6 border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-blue-900 rounded-lg shadow-lg">
              <LogoIcon className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Verification & Integrity Review</h2>
              <p className="text-xs text-gray-400">Human-in-the-loop validation of AI extraction</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 rounded-full text-gray-500 hover:bg-gray-200 dark:hover:bg-gray-700">
            <CloseIcon className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 overflow-y-auto flex-grow">
          {reviewedMarks.length > 0 && (
            <div className="mb-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-100 dark:border-blue-800 flex flex-col sm:flex-row items-center justify-between gap-4">
              <div className="text-sm text-blue-900 dark:text-blue-300">
                <p className="font-bold">Group Assignment?</p>
                <p>Apply one mark to all students in this batch.</p>
              </div>
              <div className="flex items-center gap-2 w-full sm:w-auto">
                <input 
                  type="number" 
                  value={bulkMark}
                  onChange={(e) => setBulkMark(e.target.value)}
                  placeholder="Mark"
                  className="w-24 px-3 py-2 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-900 outline-none"
                />
                <button 
                  onClick={handleBulkApply}
                  disabled={!bulkMark || isNaN(parseFloat(bulkMark))}
                  className="bg-blue-900 text-white px-4 py-2 rounded-lg hover:bg-blue-800 disabled:bg-blue-300 disabled:cursor-not-allowed transition-colors font-semibold"
                >
                  Apply to All
                </button>
              </div>
            </div>
          )}
          {reviewedMarks.length > 0 ? (
            <DataTable marks={reviewedMarks} setMarks={setReviewedMarks} maxMark={maxMark} />
          ) : (
            <p className="text-center text-gray-500 dark:text-gray-400 py-10">No data to review.</p>
          )}
        </div>

        <div className="p-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50 rounded-b-2xl">
           {duplicateCount > 0 && (
             <p className="text-sm text-center text-yellow-600 dark:text-yellow-400 mb-4">
                {duplicateCount} {duplicateCount === 1 ? 'entry' : 'entries'} with duplicate Student IDs / Names were found and will be ignored.
             </p>
           )}
          <div className="flex flex-col sm:flex-row justify-end gap-3">
            <button 
                onClick={onClose} 
                className="w-full sm:w-auto px-6 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 font-semibold"
            >
              Discard All
            </button>
            <button 
                onClick={handleConfirm}
                disabled={newUniqueMarks.length === 0}
                className="w-full sm:w-auto px-6 py-2 bg-blue-900 text-white rounded-lg hover:bg-blue-800 font-semibold disabled:bg-blue-300 disabled:cursor-not-allowed"
            >
              Add {newUniqueMarks.length} New {newUniqueMarks.length === 1 ? 'Entry' : 'Entries'} to Session
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
