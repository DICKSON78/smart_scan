import React, { useCallback } from 'react';
import { CloudIcon, TrashIcon } from './Icons';

interface ImageUploaderProps {
  files: File[];
  setFiles: React.Dispatch<React.SetStateAction<File[]>>;
}

export const ImageUploader: React.FC<ImageUploaderProps> = ({ files, setFiles }) => {
  const onFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const newFiles = Array.from(e.target.files).filter(file => file.type.startsWith('image/'));
      setFiles(prev => [...prev, ...newFiles]);
    }
  }, [setFiles]);

  const removeFile = useCallback((index: number) => {
    setFiles(prev => prev.filter((_, i) => i !== index));
  }, [setFiles]);

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.dataTransfer.files) {
      const newFiles = Array.from(e.dataTransfer.files).filter(file => file.type.startsWith('image/'));
      setFiles(prev => [...prev, ...newFiles]);
    }
  };

  return (
    <div className="space-y-4">
      <div 
        onDragOver={handleDragOver}
        onDrop={handleDrop}
        className="relative group cursor-pointer"
      >
        <input
          type="file"
          multiple
          accept="image/*"
          onChange={onFileChange}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
        />
        <div className="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-xl p-8 text-center group-hover:border-blue-900 dark:group-hover:border-blue-400 transition-all bg-gray-50 dark:bg-gray-900/50">
          <CloudIcon className="w-12 h-12 mx-auto text-gray-400 dark:text-gray-500 group-hover:text-blue-900 transition-colors" />
          <p className="mt-4 text-sm font-bold text-gray-700 dark:text-gray-300">
            Click to upload or drag and drop
          </p>
          <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
            PNG, JPG, JPEG (Max 10MB per file)
          </p>
        </div>
      </div>

      {files.length > 0 && (
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="px-4 py-2 bg-gray-50 dark:bg-gray-800/50 border-b border-gray-200 dark:border-gray-700 flex justify-between items-center">
            <span className="text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Selected Files ({files.length})</span>
            <button onClick={() => setFiles([])} className="text-xs text-red-600 dark:text-red-400 font-bold hover:underline">Clear All</button>
          </div>
          <ul className="divide-y divide-gray-100 dark:divide-gray-700 max-h-48 overflow-y-auto">
            {files.map((file, index) => (
              <li key={`${file.name}-${index}`} className="px-4 py-3 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors">
                <div className="flex items-center space-x-3 overflow-hidden">
                  <div className="w-8 h-8 rounded bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center flex-shrink-0">
                    <span className="text-[10px] font-bold text-blue-900 dark:text-blue-400 uppercase">{file.name.split('.').pop()}</span>
                  </div>
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300 truncate">{file.name}</span>
                </div>
                <button 
                  onClick={() => removeFile(index)}
                  className="p-1.5 text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-colors"
                >
                  <TrashIcon className="w-4 h-4" />
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
};
