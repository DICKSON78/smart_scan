import React, { useState, useCallback, useEffect, useMemo } from 'react';
import { LoginPage } from './components/LoginPage';
import { ImageUploader } from './components/ImageUploader';
import { DataTable } from './components/DataTable';
import { Spinner } from './components/Spinner';
import { extractMarksFromImage as extractWithGemini } from './services/geminiService';
import { extractMarksWithClaude } from './services/claudeService';
import { extractMarksFromImageWithPaddleOCR } from './services/paddleOcrService';
import { Session, StudentMark, OcrEngine, ClassListEntry, AuditEntry } from './types';
import { Header } from './components/Header';
import { RealtimeScanner } from './components/RealtimeScanner';
import { SessionManager } from './components/SessionManager';
import { ReviewModal } from './components/ReviewModal';
import { SettingsPage } from './components/SettingsPage';
import { AuditLogModal } from './components/AuditLogModal';
import * as XLSX from 'xlsx';
import { SettingsIcon, CloseIcon } from './components/Icons';
import { ExportButton } from './components/ExportButton';
import { UploadClassListModal } from './components/UploadClassListModal';
import { VoiceEntryModal } from './components/VoiceEntryModal';
import { Mic, Upload, CheckCircle2 } from 'lucide-react';

export type { OcrEngine };

// App version v1.3 - Dark Blue Theme & Scrollable IDs
const App: React.FC = () => {
  console.log("App rendering v1.3...");
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  
  // Fallback for crypto.randomUUID if not available in insecure context
  const getUUID = useCallback(() => {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
      return crypto.randomUUID();
    }
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  }, []);

  const [sessions, setSessions] = useState<Session[]>([]);
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  
  const [isClassListModalOpen, setIsClassListModalOpen] = useState<boolean>(false);
  const [isVoiceModalOpen, setIsVoiceModalOpen] = useState<boolean>(false);
  const [credits, setCredits] = useState<number>(() => {
    const value = localStorage.getItem('smartscan-credits');
    return value !== null ? parseInt(value, 10) : 50;
  });

  useEffect(() => {
    localStorage.setItem('smartscan-credits', String(credits));
  }, [credits]);
  
  const [files, setFiles] = useState<File[]>([]);
  const [pendingReviewMarks, setPendingReviewMarks] = useState<StudentMark[]>([]);
  const [isReviewModalOpen, setIsReviewModalOpen] = useState<boolean>(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState<boolean>(false);
  const [isAuditLogOpen, setIsAuditLogOpen] = useState<boolean>(false);
  
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [totalImages, setTotalImages] = useState<number>(0);
  const [processedImages, setProcessedImages] = useState<number>(0);
  const [processingStartTime, setProcessingStartTime] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [scanMode, setScanMode] = useState<'file' | 'camera'>('file');

  const [theme, setTheme] = useState(() => localStorage.getItem('smartscan-theme') || 'system');
  const [ocrEngine, setOcrEngine] = useState<OcrEngine>(() => (localStorage.getItem('smartscan-ocr-engine') as OcrEngine) || 'gemini');

  // Theme management
  useEffect(() => {
    const applyTheme = (t: string) => {
        const root = window.document.documentElement;
        if (t === 'dark' || (t === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
            root.classList.add('dark');
        } else {
            root.classList.remove('dark');
        }
    };

    applyTheme(theme);
    localStorage.setItem('smartscan-theme', theme);

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => {
        if (theme === 'system') {
            applyTheme('system');
        }
    };
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, [theme]);
  
  // OCR Engine setting persistence
  useEffect(() => {
    localStorage.setItem('smartscan-ocr-engine', ocrEngine);
  }, [ocrEngine]);

  // Load sessions and auth from storage on initial render
  useEffect(() => {
    try {
      const savedSessions = localStorage.getItem('smartscan-sessions');
      if (savedSessions) {
        setSessions(JSON.parse(savedSessions));
      }
      const savedAuth = sessionStorage.getItem('smartscan-authenticated');
      if (savedAuth === 'true') {
        setIsAuthenticated(true);
      }
    } catch (e) {
      console.error("Failed to load data from storage", e);
      localStorage.removeItem('smartscan-sessions');
      sessionStorage.removeItem('smartscan-authenticated');
    }
  }, []);

  // Save sessions to localStorage whenever they change
  useEffect(() => {
    try {
      localStorage.setItem('smartscan-sessions', JSON.stringify(sessions));
    } catch (e) {
      console.error("Failed to save sessions to localStorage", e);
    }
  }, [sessions]);
  
  const handleLogin = () => {
    setIsAuthenticated(true);
    sessionStorage.setItem('smartscan-authenticated', 'true');
    // Set default password if none exists
    if (!localStorage.getItem('smartscan-password')) {
        localStorage.setItem('smartscan-password', 'teacher');
    }
    setError(null);
  };
  
  const handleLogout = () => {
    sessionStorage.removeItem('smartscan-authenticated');
    setIsAuthenticated(false);
    setActiveSessionId(null);
    setIsSettingsOpen(false);
  };

  const handleClearAllData = () => {
    if (window.confirm('Are you sure you want to delete ALL sessions and reset your password? This cannot be undone.')) {
        localStorage.clear();
        sessionStorage.clear();
        handleLogout();
        window.location.reload();
    }
  };


  const activeSession = useMemo(() => sessions.find(s => s.id === activeSessionId), [sessions, activeSessionId]);
  
  const addLog = useCallback((sessionId: string, action: AuditEntry['action'], details: string, extras?: Partial<AuditEntry>) => {
    setSessions(prev => prev.map(s => {
      if (s.id !== sessionId) return s;
      const newLog: AuditEntry = {
        id: getUUID(),
        timestamp: new Date().toISOString(),
        action,
        details,
        ...extras
      };
      return { ...s, logs: [...(s.logs || []), newLog] };
    }));
  }, [getUUID]);

  const handleCreateSession = (name: string, maxMark: number) => {
    const newSession: Session = {
      id: getUUID(),
      name,
      maxMark,
      marks: [],
      logs: [],
      createdAt: new Date().toISOString(),
    };
    setSessions(prev => [...prev, newSession]);
    setActiveSessionId(newSession.id);
    addLog(newSession.id, 'CREATE_SESSION', `Session "${name}" created with max mark ${maxMark}`);
  };

  const handleDeleteSession = (id: string) => {
    setSessions(prev => prev.filter(s => s.id !== id));
    if (activeSessionId === id) {
        setActiveSessionId(null);
    }
  };

  const handleUpdateSessionMarks = (updatedMarks: StudentMark[]) => {
    if (!activeSessionId || !activeSession) return;
    
    const oldMarksMap = new Map(activeSession.marks.map(m => [m.id, m]));
    const newMarksMap = new Map(updatedMarks.map(m => [m.id, m]));
    const newLogs: AuditEntry[] = [];

    // Check for deletions
    activeSession.marks.forEach(m => {
      if (!newMarksMap.has(m.id)) {
        newLogs.push({
          id: getUUID(),
          timestamp: new Date().toISOString(),
          action: 'DELETE',
          details: `Record for Student ID ${m.studentId} deleted`,
          studentId: m.studentId
        });
      }
    });

    // Check for edits
    updatedMarks.forEach(m => {
      const old = oldMarksMap.get(m.id);
      if (old && (old.mark !== m.mark || old.studentId !== m.studentId)) {
        const details = old.mark !== m.mark 
          ? `Mark for Student ID ${m.studentId} edited` 
          : `Student ID changed from ${old.studentId} to ${m.studentId}`;
        
        newLogs.push({
          id: getUUID(),
          timestamp: new Date().toISOString(),
          action: 'EDIT',
          details,
          studentId: m.studentId,
          oldValue: old.mark !== m.mark ? old.mark : old.studentId,
          newValue: old.mark !== m.mark ? m.mark : m.studentId
        });
      }
    });

    setSessions(prev => prev.map(s => {
      if (s.id !== activeSessionId) return s;
      return {
        ...s,
        marks: updatedMarks,
        logs: [...(s.logs || []), ...newLogs]
      };
    }));
  };
  
  const handleConfirmReview = (reviewedMarks: StudentMark[]) => {
      if (!activeSession || !activeSessionId) return;
      const existingStudentIds = new Set(activeSession.marks.map(m => m.studentId));
      const newUniqueMarks = reviewedMarks.filter(m => !existingStudentIds.has(m.studentId));
      
      const newMarksTotal = [...activeSession.marks, ...newUniqueMarks];
      const newLog: AuditEntry = {
        id: getUUID(),
        timestamp: new Date().toISOString(),
        action: 'EXTRACT',
        details: `Successfully extracted and verified ${newUniqueMarks.length} records via ${ocrEngine.toUpperCase()}`
      };

      setSessions(prev => prev.map(s => {
        if (s.id !== activeSessionId) return s;
        return {
          ...s,
          marks: newMarksTotal,
          logs: [...(s.logs || []), newLog]
        };
      }));
      
      setIsReviewModalOpen(false);
      setPendingReviewMarks([]);
  };

  const handleUpdateClassList = (classList: ClassListEntry[]) => {
    if (!activeSessionId || !activeSession) return;
    setSessions(prev => prev.map(s => {
      if (s.id !== activeSessionId) return s;
      return {
        ...s,
        classList
      };
    }));
    addLog(activeSessionId, 'EDIT', `Class List updated with ${classList.length} student positions`);
    
    // Auto-open Voice Entry modal once class list is extracted/updated so user can continue seamlessly
    setIsVoiceModalOpen(true);
  };

  const handleAddVoiceMarks = (newMarks: StudentMark[]) => {
    if (!activeSessionId || !activeSession) return;
    
    // Merge new ones, overwriting matching studentId records
    const mergedMap = new Map<string, StudentMark>(activeSession.marks.map(m => [m.studentId, m]));
    newMarks.forEach(m => {
       mergedMap.set(m.studentId, m);
    });

    const updated = Array.from(mergedMap.values());
    const newLog: AuditEntry = {
      id: getUUID(),
      timestamp: new Date().toISOString(),
      action: 'EXTRACT',
      details: `Extracted and mapped ${newMarks.length} records via Swahili/English Voice Entry`
    };

    setSessions(prev => prev.map(s => {
      if (s.id !== activeSessionId) return s;
      return {
        ...s,
        marks: updated,
        logs: [...(s.logs || []), newLog]
      };
    }));
  };

  const fileToBase64 = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => {
        const result = reader.result as string;
        const parts = result.split(',');
        if (parts.length >= 2) {
          resolve(parts[1]);
        } else {
          reject(new Error("Failed to convert file to base64"));
        }
      };
      reader.onerror = (error) => reject(error);
    });
  };

  const processImages = useCallback(async (base64Images: {data: string, mimeType: string}[]) => {
      if (!activeSession) {
          setError('No active session. Please create or select a session first.');
          return;
      }
      setIsLoading(true);
      setTotalImages(base64Images.length);
      setProcessedImages(0);
      setProcessingStartTime(Date.now());
      setError(null);

      try {
        const allExtractedMarks: Omit<StudentMark, 'id'>[] = [];

        if (ocrEngine === 'claude') {
           // For Claude, we process individually to show progress with automated Gemini fallback in case of license/credit issues
           try {
             for (let i = 0; i < base64Images.length; i++) {
               const results = await extractMarksWithClaude([base64Images[i]], activeSession.maxMark);
               allExtractedMarks.push(...results);
               setProcessedImages(i + 1);
             }
           } catch (claudeErr: unknown) {
             console.warn("Claude extraction failed. Falling back to Gemini...", claudeErr);
             const fallbackText = "Claude extraction failed (credit balance is too low or service error). Falling back to Google Gemini to complete your requests securely...";
             setError(fallbackText);
             // Clear out whatever was partially extracted and run through Gemini instead
             allExtractedMarks.length = 0;
             setProcessedImages(0);
             for (let i = 0; i < base64Images.length; i++) {
               const img = base64Images[i];
               const marks = await extractWithGemini(img.data, img.mimeType, activeSession.maxMark);
               allExtractedMarks.push(...marks);
               setProcessedImages(i + 1);
             }
             // Auto-switch setting so future runs don't hit the failing Claude
             setOcrEngine('gemini');
           }
        } else {
           const extractFn = ocrEngine === 'gemini' ? extractWithGemini : extractMarksFromImageWithPaddleOCR;
           
           // Individual processing to update progress
           for (let i = 0; i < base64Images.length; i++) {
             const img = base64Images[i];
             const marks = await extractFn(img.data, img.mimeType, activeSession.maxMark);
             allExtractedMarks.push(...marks);
             setProcessedImages(i + 1);
           }
        }
        
        const allMarks = allExtractedMarks.map(mark => ({ 
          ...mark, 
          id: getUUID(),
          mark: (mark.mark !== null && mark.mark > activeSession.maxMark) ? null : mark.mark
        }));
        
        if(allMarks.length > 0) {
            setPendingReviewMarks(allMarks);
            setIsReviewModalOpen(true);
        } else {
            setError("No marks were found in the provided images.");
            setTimeout(() => setError(null), 3000);
        }
      } catch (err: unknown) {
        console.error(err);
        const errorMessage = err instanceof Error ? err.message : 'Failed to process images. Check network connection or API configuration.';
        setError(errorMessage);
      } finally {
        setIsLoading(false);
      }
  }, [activeSession, ocrEngine, getUUID]);

  const handleProcessFiles = useCallback(async () => {
    if (files.length === 0) return;
    try {
      const imagePayloads = await Promise.all(
          files.map(async file => {
              const base64 = await fileToBase64(file);
              return {
                  data: base64,
                  mimeType: file.type || 'image/jpeg'
              };
          })
      );
      
      const validPayloads = imagePayloads.filter(p => p.data);
      if (validPayloads.length > 0) {
          await processImages(validPayloads);
      }
      setFiles([]);
    } catch (err) {
      console.error("Error reading files:", err);
      setError("Failed to read one or more files. Please try again.");
    }
  }, [files, processImages]);
  
  const handleProcessCameraImages = useCallback(async (base64DataUrls: string[]) => {
     if (base64DataUrls.length === 0) return;
     const imagePayloads = base64DataUrls.map(url => {
         const parts = url.split(',');
         if (parts.length < 2) return null;
         
         const mimePart = url.substring(url.indexOf(':') + 1, url.indexOf(';'));
         return {
             data: parts[1],
             mimeType: mimePart || 'image/jpeg'
         };
     }).filter((p): p is {data: string, mimeType: string} => p !== null);
     
     if (imagePayloads.length > 0) {
         await processImages(imagePayloads);
     }
  }, [processImages]);

  const handleExport = (format: 'csv' | 'xlsx') => {
    if (!activeSession || activeSession.marks.length === 0) {
      setError('No data in the current session to export.');
      return;
    }
    const headers = ['Student ID', 'Mark', 'Source'];
    const data = activeSession.marks.map(m => [m.studentId, m.mark ?? '', m.source || 'scan']);
    if (format === 'csv') {
        const csvContent = [headers.join(','), ...data.map(row => row.join(','))].join('\n');
        const link = document.createElement('a');
        link.href = URL.createObjectURL(new Blob([csvContent], { type: 'text/csv;charset=utf-8;' }));
        link.download = `${activeSession.name.replace(/ /g, '_')}_marks.csv`;
        link.click();
    } else {
        const ws = XLSX.utils.aoa_to_sheet([headers, ...data]);
        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, 'Student Marks');
        XLSX.writeFile(wb, `${activeSession.name.replace(/ /g, '_')}_marks.xlsx`);
    }
  };

  if (!isAuthenticated) {
    return <LoginPage onLogin={handleLogin} error={error} setError={setError} />;
  }
  
  if (isSettingsOpen) {
      return <SettingsPage 
        onClose={() => setIsSettingsOpen(false)}
        theme={theme}
        setTheme={setTheme}
        ocrEngine={ocrEngine}
        setOcrEngine={setOcrEngine}
        onLogout={handleLogout}
        onClearAllData={handleClearAllData}
      />
  }
  
  const renderContent = () => {
      if (!activeSessionId || !activeSession) {
          return <SessionManager 
            sessions={sessions} 
            onCreateSession={handleCreateSession} 
            onSelectSession={setActiveSessionId}
            onDeleteSession={handleDeleteSession}
          />
      }

      const studentMarks = activeSession.marks;

      const progressPercentage = totalImages > 0 ? Math.round((processedImages / totalImages) * 100) : 0;
      
      let estimatedTimeRemainingText = "";
      if (processingStartTime && processedImages > 0 && totalImages > processedImages) {
          const elapsedTime = Date.now() - processingStartTime;
          const timePerImage = elapsedTime / processedImages;
          const remainingImages = totalImages - processedImages;
          const remainingTimeMs = remainingImages * timePerImage;
          
          if (remainingTimeMs < 1000) {
              estimatedTimeRemainingText = 'Almost done...';
          } else {
              const minutes = Math.floor(remainingTimeMs / 60000);
              const seconds = Math.floor((remainingTimeMs % 60000) / 1000);
              estimatedTimeRemainingText = minutes > 0 ? `${minutes}m ${seconds}s remaining` : `${seconds}s remaining`;
          }
      }

      return (
        <>
        <ReviewModal
            isOpen={isReviewModalOpen}
            onClose={() => setIsReviewModalOpen(false)}
            onConfirm={handleConfirmReview}
            marks={pendingReviewMarks}
            maxMark={activeSession.maxMark}
            existingMarks={activeSession.marks}
        />
        <UploadClassListModal
            isOpen={isClassListModalOpen}
            onClose={() => setIsClassListModalOpen(false)}
            onConfirm={handleUpdateClassList}
            existingClassList={activeSession.classList}
        />
        <VoiceEntryModal
            isOpen={isVoiceModalOpen}
            onClose={() => setIsVoiceModalOpen(false)}
            classList={activeSession.classList || []}
            existingMarks={activeSession.marks}
            maxMark={activeSession.maxMark}
            onAddMarks={handleAddVoiceMarks}
            credits={credits}
            setCredits={setCredits}
        />
        <div className="min-h-screen bg-gray-50 dark:bg-gray-900 text-gray-800 dark:text-gray-200 font-sans flex flex-col">
          <main className="flex-grow w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <Header 
                sessionName={activeSession.name}
                onSwitchSession={() => setActiveSessionId(null)}
                onViewHistory={() => setIsAuditLogOpen(true)}
            />
            
            <AuditLogModal 
                isOpen={isAuditLogOpen}
                onClose={() => setIsAuditLogOpen(false)}
                logs={activeSession.logs || []}
            />
            
            {error && (
              <div className="bg-blue-50 border border-blue-200 text-blue-800 px-4 py-3 rounded relative mb-6" role="alert">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="flex-1">
                    <span className="block font-bold mb-1">Attention</span>
                    <span className="block text-sm">{error}</span>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {/* Switch buttons based on the nature of the error */}
                    {(error.includes('extremely high demand') || error.includes('Claude AI is currently') || error.includes('credit balance')) && (
                      <>
                        {ocrEngine !== 'gemini' && (
                          <button 
                            onClick={() => { setOcrEngine('gemini'); setError(null); }}
                            className="bg-blue-900 text-white text-xs font-bold py-1.5 px-3 rounded hover:bg-blue-800 transition-colors whitespace-nowrap"
                          >
                            Use Gemini AI
                          </button>
                        )}
                        {ocrEngine !== 'claude' && (
                          <button 
                            onClick={() => { setOcrEngine('claude'); setError(null); }}
                            className="bg-gray-800 text-white text-xs font-bold py-1.5 px-3 rounded hover:bg-gray-700 transition-colors whitespace-nowrap"
                          >
                            Use Claude AI
                          </button>
                        )}
                        {ocrEngine !== 'paddle' && (
                          <button 
                            onClick={() => { setOcrEngine('paddle'); setError(null); }}
                            className="bg-gray-600 text-white text-xs font-bold py-1.5 px-3 rounded hover:bg-gray-500 transition-colors whitespace-nowrap"
                          >
                            Use PaddleOCR (Offline)
                          </button>
                        )}
                      </>
                    )}
                    {error.includes('PaddleOCR') && ocrEngine === 'paddle' && (
                      <button 
                        onClick={() => { setOcrEngine('gemini'); setError(null); }}
                        className="bg-blue-900 text-white text-xs font-bold py-1.5 px-3 rounded hover:bg-blue-800 transition-colors whitespace-nowrap"
                      >
                        Switch to Gemini AI
                      </button>
                    )}
                  </div>
                </div>
                <button onClick={() => setError(null)} className="absolute top-2 right-2 p-1">
                   <CloseIcon className="h-5 w-5 text-blue-500 hover:text-blue-700" />
                </button>
              </div>
            )}

            {/* Top Class List Integration Widget Card */}
            <div className="bg-white dark:bg-gray-800 p-5 rounded-2xl shadow-md border border-gray-105 dark:border-gray-700 mb-8 flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div className="flex items-center space-x-3.5">
                <div className="p-3 bg-teal-50 dark:bg-teal-950/25 rounded-xl text-teal-600">
                  <CheckCircle2 className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="text-xs font-bold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-0.5">Student Class List Integration</h3>
                  <div className="flex items-center gap-2">
                    {activeSession.classList && activeSession.classList.length > 0 ? (
                      <>
                        <span className="text-sm md:text-base font-extrabold text-teal-700 dark:text-teal-400">
                          {activeSession.classList.length} student positions loaded
                        </span>
                        <span className="inline-flex items-center gap-1 text-[9px] font-bold text-green-700 bg-green-50 dark:bg-green-900/15 dark:text-green-400 px-2 py-0.5 rounded-full uppercase">
                          Ready
                        </span>
                      </>
                    ) : (
                      <span className="text-sm md:text-base font-semibold text-amber-600">
                        No class list uploaded yet (required for Voice Entry)
                      </span>
                    )}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-2.5">
                <button
                  onClick={() => setIsClassListModalOpen(true)}
                  className="bg-blue-900 hover:bg-blue-800 text-white text-xs font-bold py-2.5 px-4 rounded-xl flex items-center gap-1.5 transition-all shadow-md active:scale-95 cursor-pointer whitespace-nowrap"
                >
                  <Upload className="w-4 h-4" />
                  {activeSession.classList && activeSession.classList.length > 0 ? 'Change Class List' : 'Upload Class List'}
                </button>

                <button
                  onClick={() => {
                    if (!activeSession.classList || activeSession.classList.length === 0) {
                      setError("To launch Voice Entry, you must upload a class list first. Opening upload catalog...");
                      setIsClassListModalOpen(true);
                    } else {
                      setIsVoiceModalOpen(true);
                    }
                  }}
                  className={`text-xs font-bold py-2.5 px-4 rounded-xl flex items-center gap-1.5 transition-all shadow-md active:scale-95 cursor-pointer whitespace-nowrap ${
                    activeSession.classList && activeSession.classList.length > 0
                      ? 'bg-teal-600 hover:bg-teal-700 text-white'
                      : 'bg-gray-200 dark:bg-gray-700 text-gray-400 cursor-not-allowed opacity-60'
                  }`}
                >
                  <Mic className="w-4 h-4" />
                  Voice Entry
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <div className="lg:col-span-1 space-y-6">
                 <div className="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-md">
                    <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white">1. Input Method</h2>
                    <div className="flex rounded-lg bg-gray-200 dark:bg-gray-700 p-1 mb-4">
                        <button onClick={() => setScanMode('file')} className={`w-full py-2 rounded-md text-sm font-medium transition-colors ${scanMode === 'file' ? 'bg-white dark:bg-gray-800 shadow text-blue-900' : 'text-gray-600 dark:text-gray-300 hover:bg-gray-300/50 dark:hover:bg-gray-600/50'}`}>Upload Files</button>
                        <button onClick={() => setScanMode('camera')} className={`w-full py-2 rounded-md text-sm font-medium transition-colors ${scanMode === 'camera' ? 'bg-white dark:bg-gray-800 shadow text-blue-900' : 'text-gray-600 dark:text-gray-300 hover:bg-gray-300/50 dark:hover:bg-gray-600/50'}`}>Live Scan</button>
                    </div>

                    <button 
                      onClick={() => {
                        if (!activeSession.classList || activeSession.classList.length === 0) {
                          setError("To launch Voice Entry, you must upload a class list first. Opening upload catalog...");
                          setIsClassListModalOpen(true);
                        } else {
                          setIsVoiceModalOpen(true);
                        }
                      }}
                      className="w-full bg-teal-50 dark:bg-teal-950/20 hover:bg-teal-100 dark:hover:bg-teal-900/30 border border-teal-200 dark:border-teal-900/50 text-teal-700 dark:text-teal-400 font-extrabold py-2.5 px-3 rounded-xl flex items-center justify-center gap-1.5 transition-all mb-4 shadow-sm active:scale-95"
                    >
                      <Mic className="w-4 h-4 text-teal-600 animate-pulse" />
                      <span>Voice Entry Microphone</span>
                    </button>

                    {scanMode === 'file' ? <ImageUploader files={files} setFiles={setFiles} /> : <RealtimeScanner onProcess={handleProcessCameraImages} isProcessing={isLoading} />}
                </div>

                {scanMode === 'file' && (
                    <div className="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-md">
                        <h2 className="text-xl font-semibold mb-2 text-gray-900 dark:text-white">2. Process Images</h2>
                        <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">Click below to process all uploaded images in batch.</p>
                        <button onClick={handleProcessFiles} disabled={files.length === 0 || isLoading} className="w-full bg-blue-900 text-white font-bold py-3 px-4 rounded-xl hover:bg-blue-800 disabled:bg-blue-300 disabled:cursor-not-allowed flex items-center justify-center transition-all shadow-lg active:scale-95">
                            {isLoading && scanMode === 'file' ? <Spinner /> : `Process Batch (${files.length})`}
                        </button>
                    </div>
                )}
              </div>

              <div className="lg:col-span-2 bg-white dark:bg-gray-800 p-6 rounded-xl shadow-md flex flex-col relative overflow-hidden">
                 <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white flex-shrink-0">{studentMarks.length > 0 ? `Records for ${activeSession.name}` : 'Results'}</h2>
                
                {isLoading && (
                  <div className="absolute inset-0 z-10 bg-white/80 dark:bg-gray-900/80 backdrop-blur-sm flex items-center justify-center p-6">
                    <div className="text-center w-full max-w-sm">
                      <Spinner size="lg" className="mx-auto mb-6 text-blue-900 dark:text-blue-400" />
                      <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Analyzing Mark Sheets</h3>
                      <p className="text-gray-600 dark:text-gray-400 mb-6">Processing {processedImages} of {totalImages} images...</p>
                      
                      <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3 mb-2">
                        <div 
                          className="bg-blue-900 dark:bg-blue-500 h-3 rounded-full transition-all duration-500 ease-out" 
                          style={{ width: `${progressPercentage}%` }}
                        />
                      </div>
                      
                      <div className="flex justify-between items-center text-xs font-medium">
                        <span className="text-blue-900 dark:text-blue-400">{progressPercentage}% Complete</span>
                        <span className="text-gray-500 dark:text-gray-400 italic">{estimatedTimeRemainingText}</span>
                      </div>
                    </div>
                  </div>
                )}

                {studentMarks.length > 0 ? (
                  <div className="flex-grow flex flex-col space-y-6">
                    <div className="flex-grow">
                        <DataTable marks={studentMarks} setMarks={handleUpdateSessionMarks} maxMark={activeSession.maxMark} />
                    </div>
                    <div className="flex justify-center pt-4 border-t border-gray-200 dark:border-gray-700">
                        <ExportButton onExport={handleExport} canExport={studentMarks.length > 0} />
                    </div>
                  </div>
                ) : (
                  <div className="flex-grow flex justify-center items-center h-64 border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg">
                    <p className="text-gray-500 dark:text-gray-400">Extracted data will appear here.</p>
                  </div>
                )}
              </div>
            </div>
          </main>
          <footer className="w-full text-center py-4 text-xs text-gray-500 dark:text-gray-400 border-t border-gray-200 dark:border-gray-700">
            <p>by Dickson M Chaula</p>
          </footer>
        </div>
        </>
      );
  };

  return (
    <div className="relative">
      {isAuthenticated && <button
        onClick={() => setIsSettingsOpen(true)}
        className="fixed top-4 right-4 z-30 p-2 text-gray-500 dark:text-gray-400 bg-white/50 dark:bg-gray-800/50 backdrop-blur-sm rounded-full hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
        aria-label="Open Settings"
      >
        <SettingsIcon className="w-6 h-6"/>
      </button>}
      {renderContent()}
    </div>
  );
};

export default App;
