import React, { useState } from 'react';
import { Session } from '../types';
import { PlusIcon, TrashIcon, LogoIcon } from './Icons';

interface SessionManagerProps {
  sessions: Session[];
  onCreateSession: (name: string, maxMark: number) => void;
  onSelectSession: (id: string) => void;
  onDeleteSession: (id: string) => void;
}

export const SessionManager: React.FC<SessionManagerProps> = ({ sessions, onCreateSession, onSelectSession, onDeleteSession }) => {
  const [isCreating, setIsCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newMaxMark, setNewMaxMark] = useState<number>(100);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (newName.trim()) {
      const maxMark = isNaN(newMaxMark) ? 100 : newMaxMark;
      onCreateSession(newName.trim(), maxMark);
      setNewName('');
      setNewMaxMark(100);
      setIsCreating(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 px-4 py-12 font-sans">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-12">
          <div className="inline-block bg-blue-900 p-3 rounded-2xl shadow-xl mb-4">
            <LogoIcon className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-4xl font-extrabold text-gray-900 dark:text-white tracking-tight">Your Sessions</h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">Manage your marking sessions and data</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Create New Session Card */}
          <div className="bg-white dark:bg-gray-800 rounded-3xl shadow-xl p-8 border-2 border-dashed border-blue-200 dark:border-blue-900/50 flex flex-col items-center justify-center text-center group hover:border-blue-900 dark:hover:border-blue-400 transition-all">
            {!isCreating ? (
              <button 
                onClick={() => setIsCreating(true)}
                className="w-full h-full flex flex-col items-center justify-center space-y-4 py-10"
              >
                <div className="bg-blue-100 dark:bg-blue-900/30 p-4 rounded-full group-hover:bg-blue-900 group-hover:text-white transition-all">
                  <PlusIcon className="w-8 h-8 text-blue-900 dark:text-blue-400 group-hover:text-white" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-gray-900 dark:text-white">Create New Session</h3>
                  <p className="text-sm text-gray-500 dark:text-gray-400">Start a new marking batch</p>
                </div>
              </button>
            ) : (
              <form onSubmit={handleSubmit} className="w-full space-y-4">
                <div className="text-left">
                  <label htmlFor="sessionName" className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Session Name</label>
                  <input
                    id="sessionName"
                    autoFocus
                    type="text"
                    placeholder="e.g., Math Midterm 2024"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl focus:ring-2 focus:ring-blue-900 outline-none transition-all text-gray-900 dark:text-white"
                    required
                  />
                </div>
                <div className="text-left">
                  <label htmlFor="maxMark" className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Max Mark</label>
                  <input
                    id="maxMark"
                    type="number"
                    value={isNaN(newMaxMark) ? '' : newMaxMark}
                    onChange={(e) => {
                      const val = e.target.value;
                      setNewMaxMark(val === '' ? NaN : parseInt(val));
                    }}
                    className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl focus:ring-2 focus:ring-blue-900 outline-none transition-all text-gray-900 dark:text-white"
                    required
                    min="1"
                  />
                </div>
                <div className="flex gap-2 pt-2">
                  <button 
                    type="button" 
                    onClick={() => setIsCreating(false)}
                    className="flex-1 px-4 py-3 bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 font-bold rounded-xl hover:bg-gray-200 dark:hover:bg-gray-600 transition-all"
                  >
                    Cancel
                  </button>
                  <button 
                    type="submit"
                    className="flex-2 px-6 py-3 bg-blue-900 text-white font-bold rounded-xl hover:bg-blue-800 shadow-lg shadow-blue-200 dark:shadow-none transition-all"
                  >
                    Create
                  </button>
                </div>
              </form>
            )}
          </div>

          {/* Existing Sessions */}
          {sessions.map((session) => (
            <div 
              key={session.id} 
              className="bg-white dark:bg-gray-800 rounded-3xl shadow-xl p-8 border border-gray-100 dark:border-gray-700 flex flex-col justify-between hover:shadow-2xl transition-all group"
            >
              <div>
                <div className="flex justify-between items-start mb-4">
                  <div className="bg-blue-50 dark:bg-blue-900/20 px-3 py-1 rounded-full">
                    <span className="text-[10px] font-bold text-blue-900 dark:text-blue-400 uppercase tracking-widest">Marking Session</span>
                  </div>
                  <button 
                    onClick={(e) => {
                      e.stopPropagation();
                      if(window.confirm('Delete this session and all its data?')) onDeleteSession(session.id);
                    }}
                    className="text-gray-400 hover:text-red-500 p-2 rounded-full hover:bg-red-50 dark:hover:bg-red-900/20 transition-all"
                  >
                    <TrashIcon className="w-5 h-5" />
                  </button>
                </div>
                <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-1 truncate">{session.name}</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">
                  Created on {new Date(session.createdAt).toLocaleDateString()}
                </p>
                
                <div className="grid grid-cols-2 gap-4 mb-8">
                  <div className="bg-gray-50 dark:bg-gray-900/50 p-3 rounded-2xl">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-1">Records</p>
                    <p className="text-xl font-bold text-gray-900 dark:text-white">{session.marks.length}</p>
                  </div>
                  <div className="bg-gray-50 dark:bg-gray-900/50 p-3 rounded-2xl">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-1">Max Mark</p>
                    <p className="text-xl font-bold text-gray-900 dark:text-white">{session.maxMark}</p>
                  </div>
                </div>
              </div>

              <button 
                onClick={() => onSelectSession(session.id)}
                className="w-full py-4 bg-blue-900 text-white font-bold rounded-2xl hover:bg-blue-800 transition-all shadow-lg"
              >
                Open Session
              </button>
            </div>
          ))}
        </div>
        
        {sessions.length === 0 && !isCreating && (
          <div className="mt-12 text-center p-12 bg-white dark:bg-gray-800 rounded-3xl shadow-inner border-2 border-dashed border-gray-200 dark:border-gray-700">
            <p className="text-gray-500 dark:text-gray-400 text-lg">No sessions found. Create your first one to get started!</p>
          </div>
        )}
      </div>
    </div>
  );
};
