import React, { useState, useEffect, useRef } from 'react';
import { 
  Mic, Check, Edit2, AlertCircle, RefreshCw, Coins
} from 'lucide-react';
import { ruleBasedVoiceParser } from '../utils/voiceParser';
import { ClassListEntry, StudentMark } from '../types';

interface ISpeechRecognitionResult {
  isFinal: boolean;
  length: number;
  [index: number]: {
    transcript: string;
  };
}

interface ISpeechRecognitionEvent {
  resultIndex: number;
  results: {
    length: number;
    [index: number]: ISpeechRecognitionResult;
  };
}

interface ISpeechRecognition {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  onstart: (() => void) | null;
  onresult: ((event: ISpeechRecognitionEvent) => void) | null;
  onerror: ((e: { error: string }) => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
}

interface VoiceEntryModalProps {
  isOpen: boolean;
  onClose: () => void;
  classList: ClassListEntry[];
  existingMarks: StudentMark[];
  maxMark: number;
  onAddMarks: (newMarks: StudentMark[]) => void;
  credits: number;
  setCredits: React.Dispatch<React.SetStateAction<number>>;
}

interface ExtractedFeedback {
  name: string;
  position: number;
  mark: number;
  success: boolean;
  reason?: string;
}

export const VoiceEntryModal: React.FC<VoiceEntryModalProps> = ({
  isOpen,
  onClose,
  classList,
  existingMarks,
  maxMark,
  onAddMarks,
  credits,
  setCredits
}) => {
  const [isRecording, setIsRecording] = useState(false);
  const [transcribedText, setTranscribedText] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  
  // Results of the latest voice segment
  const [lastBatchResults, setLastBatchResults] = useState<ExtractedFeedback[]>([]);
  
  // Direct direct student manual edit states
  const [editingStudent, setEditingStudent] = useState<ClassListEntry | null>(null);
  const [editMarkVal, setEditMarkVal] = useState<string>('');
  
  const [showInsufficientCredits, setShowInsufficientCredits] = useState(false);

  const mediaRecorderRef = useRef<ISpeechRecognition | null>(null);
  const transcriptRef = useRef('');
  const creditDeductedRef = useRef(false);

  // Stats
  const totalStudents = classList.length;
  const markedCount = classList.filter(item => 
    existingMarks.some(em => em.studentId === item.student && em.mark !== null)
  ).length;
  const progressPercentage = totalStudents > 0 ? Math.round((markedCount / totalStudents) * 100) : 0;

  // Clean state when modal opens
  useEffect(() => {
    if (isOpen) {
      setTranscribedText('');
      setErrorMsg(null);
      setLastBatchResults([]);
      setEditingStudent(null);
    } else {
      stopRecordingSilently();
    }
  }, [isOpen]);

  const stopRecordingSilently = () => {
    setIsRecording(false);
    if (mediaRecorderRef.current) {
      try {
        mediaRecorderRef.current.onend = null;
        mediaRecorderRef.current.onerror = null;
        mediaRecorderRef.current.stop();
      } catch (e) {
        console.warn("Silent stop recognition warning", e);
      }
      mediaRecorderRef.current = null;
    }
  };

  const triggerRecording = () => {
    if (isRecording) {
      stopRecording();
      return;
    }

    if (credits <= 0) {
      setShowInsufficientCredits(true);
      return;
    }

    const SpeechRecognition = (window as unknown as { SpeechRecognition?: new () => ISpeechRecognition; webkitSpeechRecognition?: new () => ISpeechRecognition }).SpeechRecognition || 
                            (window as unknown as { SpeechRecognition?: new () => ISpeechRecognition; webkitSpeechRecognition?: new () => ISpeechRecognition }).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setErrorMsg("Your web browser does not support Speech Recognition. Please use Chrome, Edge, or Safari.");
      return;
    }

    setIsRecording(true);
    setTranscribedText('');
    transcriptRef.current = '';
    setErrorMsg(null);
    setLastBatchResults([]);
    creditDeductedRef.current = false;

    try {
      const rec = new SpeechRecognition();
      rec.continuous = true; 
      rec.interimResults = true;
      rec.lang = 'sw-TZ'; // Swahili as primary default, handles both language contexts elegantly

      mediaRecorderRef.current = rec;

      rec.onstart = () => {
        // Deduct 1 credit upon recording start
        setCredits(prev => {
          const updated = Math.max(0, prev - 1);
          localStorage.setItem('smartscan-credits', String(updated));
          return updated;
        });
        creditDeductedRef.current = true;
      };

      rec.onresult = (event: ISpeechRecognitionEvent) => {
        let interimTranscript = '';
        let finalTranscript = '';
        
        for (let i = event.resultIndex; i < event.results.length; ++i) {
          const transcriptText = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalTranscript += transcriptText + ' ';
          } else {
            interimTranscript += transcriptText;
          }
        }
        
        const combined = (finalTranscript + interimTranscript).trim();
        setTranscribedText(combined);
        transcriptRef.current = combined;
      };

      rec.onerror = (e: { error: string }) => {
        console.error("Speech Recognition error:", e);
        setIsRecording(false);
        setErrorMsg(`Microphone error: ${e.error === 'not-allowed' ? 'Authorization denied' : e.error || 'Check microphone standard permissions'}`);
        
        // Refund credit
        if (creditDeductedRef.current) {
          setCredits(prev => {
            const updated = prev + 1;
            localStorage.setItem('smartscan-credits', String(updated));
            return updated;
          });
          creditDeductedRef.current = false;
        }
      };

      rec.onend = async () => {
        setIsRecording(false);
        const finalTxt = transcriptRef.current;
        if (finalTxt.trim()) {
          await processTranscribedText(finalTxt);
        } else {
          // Refund credit for silent / empty clicks
          if (creditDeductedRef.current) {
            setCredits(prev => {
              const updated = prev + 1;
              localStorage.setItem('smartscan-credits', String(updated));
              return updated;
            });
            creditDeductedRef.current = false;
          }
        }
      };

      rec.start();

    } catch (err) {
      console.error(err);
      setErrorMsg("Failed to open audio recognition pipeline.");
      setIsRecording(false);
    }
  };

  const stopRecording = () => {
    setIsRecording(false);
    if (mediaRecorderRef.current) {
      try {
        mediaRecorderRef.current.stop();
      } catch (err) {
        console.warn("Stop speed recognition error", err);
      }
    }
  };

  const processTranscribedText = async (txt: string) => {
    if (!txt.trim()) return;
    setIsProcessing(true);
    setErrorMsg(null);
    setLastBatchResults([]);

    try {
      // 1. Extract using robust rule-based Swahili/English regex
      let extracted = ruleBasedVoiceParser(txt);

      // 2. Fetch from Gemini fallback is rule-mapping missed
      if (extracted.length === 0 && navigator.onLine) {
        try {
          const response = await fetch('/api/extract-marks-voice', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ text: txt, maxMark })
          });

          if (response.ok) {
            const geminiExtracted = await response.json();
            if (Array.isArray(geminiExtracted)) {
              extracted = geminiExtracted;
            }
          }
        } catch (apiErr) {
          console.warn("Gemini backup extractor error:", apiErr);
        }
      }

      if (extracted.length === 0) {
        setErrorMsg("Couldn't recognize any student index and score in speech. Speak format like: 'Namba moja sitini', 'number five forty five'.");
        setIsProcessing(false);
        return;
      }

      const feedItems: ExtractedFeedback[] = [];
      const marksToApply: StudentMark[] = [];

      for (const pair of extracted) {
        const studentObj = classList.find(s => s.position === pair.position);
        if (!studentObj) {
          feedItems.push({
            name: `Unknown index`,
            position: pair.position,
            mark: pair.mark || 0,
            success: false,
            reason: `Position ${pair.position} does not exist in roster`
          });
          continue;
        }

        if (pair.mark === null) {
          feedItems.push({
            name: studentObj.student,
            position: studentObj.position,
            mark: 0,
            success: false,
            reason: `Unrecognized mark score`
          });
          continue;
        }

        if (pair.mark > maxMark) {
          feedItems.push({
            name: studentObj.student,
            position: studentObj.position,
            mark: pair.mark,
            success: false,
            reason: `Score exceeds maximum limit of ${maxMark}`
          });
          continue;
        }

        // Correctly graded!
        marksToApply.push({
          id: `${studentObj.position}-${Date.now()}-${Math.floor(Math.random() * 900 + 100)}`,
          studentId: studentObj.student,
          mark: pair.mark,
          source: 'voice'
        });

        feedItems.push({
          name: studentObj.student,
          position: studentObj.position,
          mark: pair.mark,
          success: true
        });
      }

      if (marksToApply.length > 0) {
        onAddMarks(marksToApply);
      }

      setLastBatchResults(feedItems);

    } catch (err) {
      console.error(err);
      setErrorMsg("An error occurred while parsing spoken audio words.");
    } finally {
      setIsProcessing(false);
    }
  };

  const openDirectEdit = (item: ClassListEntry) => {
    setEditingStudent(item);
    const existing = existingMarks.find(em => em.studentId === item.student);
    setEditMarkVal(existing && existing.mark !== null ? String(existing.mark) : '');
  };

  const saveDirectEdit = () => {
    if (!editingStudent) return;
    const num = parseFloat(editMarkVal);
    const scoreVal = isNaN(num) ? null : num;

    const transformed: StudentMark = {
      id: `${editingStudent.position}-${Date.now()}`,
      studentId: editingStudent.student,
      mark: scoreVal,
      source: 'manual'
    };

    onAddMarks([transformed]);
    setEditingStudent(null);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-40 bg-gray-900/40 backdrop-blur-sm flex justify-center items-center p-4">
      {/* Insufficient Credits Dialog */}
      {showInsufficientCredits && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex justify-center items-center p-4">
          <div className="bg-white dark:bg-gray-800 rounded-2xl w-full max-w-sm p-6 text-center border border-gray-100 dark:border-gray-700 shadow-xl">
            <Coins className="w-12 h-12 text-amber-500 mx-auto mb-4 animate-bounce" />
            <h4 className="text-lg font-bold text-gray-900 dark:text-white mb-2">Insufficient Balance!</h4>
            <p className="text-xs text-gray-505 dark:text-gray-400 mb-6 font-medium leading-relaxed">
              Your voice-entry balance has drained. Refill now to trigger rapid transcript matching.
            </p>
            <div className="flex gap-2 justify-center">
              <button 
                onClick={() => {
                  setCredits(50);
                  localStorage.setItem('smartscan-credits', '50');
                  setShowInsufficientCredits(false);
                }}
                className="bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold py-2.5 px-4 rounded-xl transition-all cursor-pointer"
              >
                Refill 50 Credits For Free
              </button>
              <button 
                onClick={() => setShowInsufficientCredits(false)}
                className="bg-gray-100 dark:bg-gray-750 text-gray-700 dark:text-gray-250 hover:bg-gray-200 text-xs font-bold py-2.5 px-4 rounded-xl transition-all cursor-pointer"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Manual Quick Override Dialog */}
      {editingStudent && (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-sm flex justify-center items-center p-4">
          <div className="bg-white dark:bg-gray-800 rounded-2xl w-full max-w-sm p-6 border border-gray-100 dark:border-gray-700 shadow-xl">
            <h4 className="text-sm font-extrabold text-gray-900 dark:text-white mb-2 flex items-center gap-1.5 uppercase tracking-wide">
              <Edit2 className="w-4 h-4 text-teal-600" />
              Adjust Student Mark
            </h4>
            <p className="text-xs text-gray-505 dark:text-gray-450 mb-4 font-medium leading-relaxed">
              Directly override or assign marks for <strong className="text-gray-800 dark:text-gray-200">{editingStudent.student}</strong>.
            </p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-1">Score Value (Max: {maxMark})</label>
                <input
                  type="number"
                  step="0.5"
                  min="0"
                  max={maxMark}
                  value={editMarkVal}
                  onChange={(e) => setEditMarkVal(e.target.value)}
                  className="w-full bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl px-3.5 py-2.5 text-sm font-bold text-gray-900 dark:text-white focus:outline-none focus:ring-1 focus:ring-teal-600 focus:border-teal-600"
                  placeholder="e.g. 45"
                />
              </div>
            </div>

            <div className="flex gap-2 justify-end mt-6">
              <button 
                onClick={() => setEditingStudent(null)}
                className="bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 text-gray-700 dark:text-gray-200 text-xs font-bold py-2 px-4 rounded-xl transition-all cursor-pointer"
              >
                Cancel
              </button>
              <button 
                onClick={saveDirectEdit}
                className="bg-teal-600 hover:bg-teal-700 text-white text-xs font-extrabold py-2 px-5 rounded-xl transition-all cursor-pointer"
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Main Container */}
      <div className="bg-white dark:bg-gray-850 border border-gray-100 dark:border-gray-700 rounded-2xl w-full max-w-4xl h-[82vh] flex flex-col overflow-hidden shadow-2xl relative">
        
        {/* Core Header */}
        <div className="p-4 bg-gray-50 dark:bg-gray-800/80 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <h3 className="text-sm font-black text-gray-800 dark:text-white tracking-wide uppercase flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              Voice Grade Entry Workspace
            </h3>
            <div className="bg-teal-100 dark:bg-teal-900/35 text-teal-850 dark:text-teal-400 text-[11px] font-extrabold px-3 py-1 rounded-full flex items-center gap-1">
              <Coins className="w-3.5 h-3.5 text-teal-600" />
              <span>{credits} Credits</span>
            </div>
          </div>
          
          <button 
            onClick={onClose}
            className="p-1 px-3 py-1.5 text-xs font-bold text-gray-500 hover:text-gray-700 dark:hover:text-gray-200 border border-gray-200 dark:border-gray-650 rounded-xl bg-white dark:bg-gray-750 hover:bg-gray-50 dark:hover:bg-gray-700 transition cursor-pointer"
          >
            Close Session
          </button>
        </div>

        {/* Global Progress Indicators */}
        <div className="bg-gray-50/50 dark:bg-gray-900/10 p-3 px-6 flex items-center justify-between border-b border-gray-105 dark:border-gray-700/60 font-sans">
          <div className="w-full flex items-center gap-4">
            <div className="text-xs font-bold text-gray-501 dark:text-gray-400 whitespace-nowrap">
              Grades Saved: <span className="text-teal-600 dark:text-teal-400 font-black">{markedCount}</span> / {totalStudents} Students
            </div>
            <div className="flex-1 bg-gray-200 dark:bg-gray-700 h-2 rounded-full overflow-hidden">
              <div 
                className="h-full bg-teal-555 transition-all duration-300"
                style={{ width: `${progressPercentage}%`, backgroundColor: '#0d9488' }}
              />
            </div>
            <div className="text-xs font-bold text-teal-600 dark:text-teal-400 tracking-wider">
              {progressPercentage}% Built
            </div>
          </div>
        </div>

        {/* Interactive Workspace: Dual Column Layout */}
        <div className="flex-1 flex overflow-hidden min-h-0">
          
          {/* Left Panel: List of Names */}
          <div className="w-2/5 border-r border-gray-100 dark:border-gray-700 overflow-y-auto p-4 space-y-2 bg-gray-50/40 dark:bg-gray-900/10">
            <h4 className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-3 flex items-center justify-between">
              <span>Student Roster list</span>
              <span className="bg-gray-20/5 dark:bg-gray-750 text-gray-505 dark:text-gray-400 px-2 py-0.5 rounded font-mono">
                Total: {totalStudents}
              </span>
            </h4>

            <div className="space-y-1.5">
              {classList.map((item) => {
                const existingMark = existingMarks.find(em => em.studentId === item.student);
                const hasScore = existingMark !== undefined && existingMark.mark !== null;
                const score = hasScore ? existingMark.mark : null;

                return (
                  <div
                    key={item.position}
                    onClick={() => openDirectEdit(item)}
                    className={`flex items-center justify-between px-3 py-2 border rounded-xl cursor-pointer transition-all hover:border-gray-300 dark:hover:border-gray-600 active:scale-[0.99] ${
                      hasScore 
                        ? 'bg-emerald-50/30 dark:bg-emerald-950/10 border-emerald-200/50 dark:border-emerald-900/20' 
                        : 'bg-white dark:bg-gray-800 border-gray-100 dark:border-gray-700'
                    }`}
                  >
                    <div className="flex items-center space-x-2 overflow-hidden">
                      <span className="text-[11px] font-mono font-bold text-gray-400 bg-gray-100 dark:bg-gray-700 px-1.5 py-0.5 rounded">
                        {item.position}
                      </span>
                      <span className="text-xs font-semibold text-gray-700 dark:text-gray-250 truncate max-w-[150px]" title={item.student}>
                        {item.student}
                      </span>
                    </div>

                    <div className="flex items-center space-x-1">
                      {hasScore ? (
                        <div className="flex items-center space-x-1">
                          <span className="text-xs font-black text-teal-600 dark:text-teal-400">
                            {score}
                          </span>
                          <Check className="w-3.5 h-3.5 text-emerald-500 fill-none" />
                        </div>
                      ) : (
                        <span className="text-[10px] text-gray-400 italic">No grade</span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Right Panel: Clean Mic Controller & Transcription */}
          <div className="flex-1 flex flex-col p-6 overflow-y-auto space-y-6">
            
            {/* Minimalist Microphonic Center Area */}
            <div className="flex flex-col items-center justify-center p-8 bg-gray-50/50 dark:bg-gray-900/10 border border-gray-100 dark:border-gray-700 rounded-2xl text-center space-y-6 relative min-h-[250px]">
              
              {/* Mic state beacon */}
              <div className="absolute right-4 top-4">
                {isRecording ? (
                  <span className="bg-red-500/10 text-red-600 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full flex items-center gap-1 animate-pulse">
                    <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-ping" />
                    Listening
                  </span>
                ) : (
                  <span className="bg-gray-100 dark:bg-gray-750 text-gray-400 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full">
                    Microphone Idle
                  </span>
                )}
              </div>

              {/* Large visually beautiful mic button */}
              <button
                type="button"
                onClick={triggerRecording}
                className={`relative w-28 h-28 rounded-full flex items-center justify-center transition-all cursor-pointer ${
                  isRecording 
                    ? 'bg-red-600 text-white shadow-xl shadow-red-600/20 ring-8 ring-red-105 animate-pulse' 
                    : 'bg-teal-600 hover:bg-teal-700 hover:scale-[1.03] text-white shadow-lg active:scale-95'
                }`}
              >
                {isRecording ? (
                  <Mic className="w-12 h-12 text-white animate-bounce" />
                ) : (
                  <Mic className="w-12 h-12 text-white" />
                )}
              </button>

              <div className="space-y-1 max-w-sm">
                <h4 className="text-sm font-extrabold text-gray-700 dark:text-gray-200">
                  {isRecording ? 'Listening...' : 'Click main microphone to record grade batch'}
                </h4>
                <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed font-semibold">
                  {isRecording 
                    ? 'Speak clearly. Click again of stop & process text immediately!' 
                    : 'Speak like: "Namba moja 45, Nambari pili hamsini, Namba tatu sitini"'
                  }
                </p>
              </div>
            </div>

            {/* Real-time Transcription Feedback Box */}
            {transcribedText && (
              <div className="p-4 bg-gray-50 dark:bg-gray-900 border border-gray-150 dark:border-gray-700 rounded-xl space-y-1.5">
                <div className="text-[10px] font-bold tracking-widest text-teal-650 uppercase dark:text-teal-400">
                  {isRecording ? 'Transcription Word Map (Real-Time):' : 'Processed Spoken Text Phrase:'}
                </div>
                <p className="text-xs font-mono font-bold text-gray-800 dark:text-gray-250 italic leading-relaxed">
                  "{transcribedText}"
                </p>
              </div>
            )}

            {/* Micro loaders if analyzing */}
            {isProcessing && (
              <div className="flex items-center justify-center py-4 space-x-2.5 text-xs text-teal-600 font-extrabold animate-pulse">
                <RefreshCw className="w-4 h-4 animate-spin" />
                <span>Interacting with speech recognition analysis engine...</span>
              </div>
            )}

            {/* Beautiful feedback list of latest batch results */}
            {lastBatchResults.length > 0 && (
              <div className="border border-gray-150 dark:border-gray-700 rounded-xl overflow-hidden shadow-sm">
                <div className="p-2.5 bg-gray-50 dark:bg-gray-800 border-b border-gray-150 dark:border-gray-750 text-[10px] font-bold text-gray-505 uppercase tracking-wider">
                  Latest Voice Batch matched updates:
                </div>
                <div className="divide-y divide-gray-100 dark:divide-gray-700 bg-white dark:bg-gray-850">
                  {lastBatchResults.map((res, idx) => (
                    <div key={idx} className="p-3 text-xs flex items-center justify-between font-semibold">
                      <div className="flex items-center gap-2">
                        <span className="font-mono bg-gray-100 dark:bg-gray-700 text-gray-500 px-1 rounded text-[10px]">
                          Pos {res.position}
                        </span>
                        <span className="text-gray-700 dark:text-gray-200">{res.name}</span>
                      </div>
                      
                      <div className="flex items-center gap-1.5">
                        {res.success ? (
                          <>
                            <span className="text-teal-650 dark:text-teal-400 font-extrabold font-mono">+{res.mark} marks</span>
                            <span className="text-[9px] font-extrabold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400 px-2 py-0.5 rounded-full uppercase">Applied</span>
                          </>
                        ) : (
                          <>
                            <span className="text-red-500 font-mono text-[11px]">{res.reason || 'Failed'}</span>
                            <span className="text-[9px] font-extrabold bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400 px-1.5 py-0.5 rounded-full uppercase font-sans">Error</span>
                          </>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Error notifications */}
            {errorMsg && (
              <div className="p-4 bg-red-50/50 dark:bg-red-950/15 border border-red-200 dark:border-red-900/40 text-red-700 dark:text-red-400 text-xs rounded-xl flex items-start gap-2 font-semibold">
                <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-red-500" />
                <span>{errorMsg}</span>
              </div>
            )}

            {/* Manual correction placeholder */}
            <div className="text-[11px] text-gray-400 italic text-center text-sans pt-4 border-t border-gray-100 dark:border-gray-700">
              💡 Correct scores anytime by directly clicking on any student row in the Roster.
            </div>

          </div>
        </div>

      </div>
    </div>
  );
};
