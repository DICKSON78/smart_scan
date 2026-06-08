import React, { useState, useEffect } from 'react';
import { CloseIcon, CloudIcon } from './Icons';
import { Spinner } from './Spinner';
import * as XLSX from 'xlsx';
import mammoth from 'mammoth';
import { ClassListEntry } from '../types';
import { 
  Clipboard, Sparkles, FileSpreadsheet, CheckCircle2, AlertCircle, Trash2 
} from 'lucide-react';

interface UploadClassListModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (classList: ClassListEntry[]) => void;
  existingClassList?: ClassListEntry[];
}

const DEMO_CLASS_LIST: ClassListEntry[] = [
  { position: 1, student: "Amina Juma Hassan" },
  { position: 2, student: "Dickson Michael Chaula" },
  { position: 3, student: "Emmanuel Peter Mwambene" },
  { position: 4, student: "Faraja Said Kiluvya" },
  { position: 5, student: "Grace John Masanje" },
  { position: 6, student: "Hamisi Selemani Bakari" },
  { position: 7, student: "Irene Joseph Lyimo" },
  { position: 8, student: "Juma Omari Ramadhani" },
  { position: 9, student: "Kelvin William Mushi" },
  { position: 10, student: "Lilian Aloyce Chuwa" },
  { position: 11, student: "Moses David Mwakalebela" },
  { position: 12, student: "Neema Charles Swai" },
  { position: 13, student: "Oscar Thomas Temu" },
  { position: 14, student: "Pili Rashid Simba" },
  { position: 15, student: "Richard Edward Mboya" }
];

export const UploadClassListModal: React.FC<UploadClassListModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  existingClassList
}) => {
  const [activeTab, setActiveTab] = useState<'upload' | 'paste' | 'demo'>('upload');
  
  const [file, setFile] = useState<File | null>(null);
  const [isParsing, setIsParsing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [parsedStudents, setParsedStudents] = useState<ClassListEntry[]>(existingClassList || []);
  const [isOnline, setIsOnline] = useState<boolean>(navigator.onLine);

  // Directly copy/paste text state
  const [pastedText, setPastedText] = useState<string>('');

  // Excel multi-column selection states
  const [excelRows, setExcelRows] = useState<unknown[][]>([]);
  const [excelColumns, setExcelColumns] = useState<{ index: number; label: string; preview: string }[]>([]);
  const [excelSheets, setExcelSheets] = useState<string[]>([]);
  const [selectedSheetName, setSelectedSheetName] = useState<string>('');
  const [selectedColIdx, setSelectedColIdx] = useState<number>(-1);
  const [headerRowIdx, setHeaderRowIdx] = useState<number>(-1);
  const [workbookInstance, setWorkbookInstance] = useState<XLSX.WorkBook | null>(null);

  useEffect(() => {
    const handleOnlineStatus = () => setIsOnline(navigator.onLine);
    window.addEventListener('online', handleOnlineStatus);
    window.addEventListener('offline', handleOnlineStatus);
    return () => {
      window.removeEventListener('online', handleOnlineStatus);
      window.removeEventListener('offline', handleOnlineStatus);
    };
  }, []);

  useEffect(() => {
    if (isOpen) {
      setParsedStudents(existingClassList || []);
      setFile(null);
      setError(null);
      setPastedText('');
      setExcelRows([]);
      setExcelColumns([]);
      setExcelSheets([]);
      setSelectedSheetName('');
      setSelectedColIdx(-1);
      setHeaderRowIdx(-1);
      setWorkbookInstance(null);
    }
  }, [isOpen, existingClassList]);

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

  const parseWordDocLocal = async (file: File): Promise<ClassListEntry[]> => {
    const arrayBuffer = await file.arrayBuffer();
    const result = await mammoth.extractRawText({ arrayBuffer });
    const text = result.value;
    
    // Split lines and parse
    const lines = text.split('\n');
    const students: ClassListEntry[] = [];
    let currentPosition = 1;

    for (let line of lines) {
      line = line.trim();
      if (!line) continue;
      
      let student = line;
      let pos = currentPosition;
      
      const numberPrefixMatch = line.match(/^(\d+)[\s.)\-_/:\\]+(.*)$/);
      if (numberPrefixMatch) {
        pos = parseInt(numberPrefixMatch[1], 10);
        student = numberPrefixMatch[2].trim();
      }

      const lower = student.toLowerCase();
      if (
        lower === 'student name' || 
        lower === 'name' || 
        lower === 'registration number' || 
        lower === 'reg no' || 
        lower === 'student' || 
        lower === 'class list' || 
        lower === 'names' ||
        lower === 'registration' ||
        lower === 'reg_no' ||
        lower === 's/n' ||
        lower === 'sn'
      ) {
        continue;
      }

      if (student) {
        students.push({
          position: pos,
          student: student
        });
        currentPosition = Math.max(currentPosition, pos) + 1;
      }
    }

    // Force exact positions 1, 2, 3...
    return students.map((s, idx) => ({
      position: idx + 1,
      student: s.student
    }));
  };

  const getStudentsFromRowsAndColumn = (rows: unknown[][], colIdx: number, headerRow: number): ClassListEntry[] => {
    const students: string[] = [];
    const startRowIdx = headerRow !== -1 ? headerRow + 1 : 0;
    
    for (let rIdx = startRowIdx; rIdx < rows.length; rIdx++) {
      const row = rows[rIdx];
      if (!Array.isArray(row)) continue;
      if (row.length <= colIdx || colIdx < 0) continue;
      
      const val = row[colIdx];
      if (val !== undefined && val !== null) {
        const strVal = String(val).trim();
        if (strVal) {
          const lower = strVal.toLowerCase();
          
          if (
            lower === 'name' || 
            lower === 'student' ||
            lower === 'jina' || 
            lower === 'full name' || 
            lower === 'student name' || 
            lower === 'majina' || 
            lower === 'mwanafunzi' ||
            lower === 'registration number' ||
            lower === 'reg no' ||
            lower === 'reg. no' ||
            lower === 's/n' ||
            lower === 'sn' ||
            lower === 'namba' ||
            lower === 'no' ||
            lower === 'number' ||
            lower === 'registration' ||
            lower === 'reg_no'
          ) {
            continue;
          }
          
          // Skip pure numbers (usually SNs)
          if (!isNaN(Number(strVal))) {
            continue;
          }
          
          students.push(strVal);
        }
      }
    }
    
    return students.map((s, idx) => ({
      position: idx + 1,
      student: s
    }));
  };

  const processExcelSheet = (wb: XLSX.WorkBook, sheetName: string): ClassListEntry[] => {
    const worksheet = wb.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json<unknown[]>(worksheet, { header: 1 });
    setExcelRows(rows);

    if (rows.length === 0) {
      setExcelColumns([]);
      setSelectedColIdx(-1);
      setParsedStudents([]);
      return [];
    }

    // 1. Scan column metadata
    const colStats: { [key: number]: string[] } = {};
    rows.slice(0, 30).forEach(row => {
      if (!Array.isArray(row)) return;
      row.forEach((val, colIdx) => {
        if (val !== undefined && val !== null) {
          const strVal = String(val).trim();
          if (strVal) {
            if (!colStats[colIdx]) colStats[colIdx] = [];
            if (colStats[colIdx].length < 3) {
              colStats[colIdx].push(strVal);
            }
          }
        }
      });
    });

    const columnsList = Object.keys(colStats).map(colKey => {
      const colIdx = Number(colKey);
      const previews = colStats[colIdx];
      const previewText = previews.join(', ');
      const firstCell = previews[0] || '';
      let label = `Column ${colIdx + 1}`;
      if (firstCell && firstCell.length < 30 && isNaN(Number(firstCell))) {
        label = `Column ${colIdx + 1} ("${firstCell}")`;
      }
      return { index: colIdx, label, preview: previewText };
    });

    setExcelColumns(columnsList);

    // Auto-detect column containing names
    let autoColIdx = -1;
    let autoHeaderRow = -1;

    // Scan for obvious headers
    for (let rIdx = 0; rIdx < Math.min(rows.length, 25); rIdx++) {
      const row = rows[rIdx];
      if (!Array.isArray(row)) continue;
      for (let cIdx = 0; cIdx < row.length; cIdx++) {
        const val = row[cIdx];
        if (val !== undefined && val !== null) {
          const lowerStr = String(val).trim().toLowerCase();
          if (
            lowerStr === 'name' || 
            lowerStr === 'student' ||
            lowerStr === 'jina' || 
            lowerStr === 'full name' || 
            lowerStr === 'student name' || 
            lowerStr === 'majina' || 
            lowerStr === 'mwanafunzi' ||
            lowerStr === 'registration number' ||
            lowerStr === 'reg no' ||
            lowerStr === 'reg. no' ||
            lowerStr.includes('full name') ||
            lowerStr.includes('student name') ||
            lowerStr.endsWith('name') ||
            lowerStr.startsWith('jina') ||
            lowerStr === 'registration' ||
            lowerStr === 'reg_no'
          ) {
            autoColIdx = cIdx;
            autoHeaderRow = rIdx;
            break;
          }
        }
      }
      if (autoColIdx !== -1) {
        break;
      }
    }

    // Heuristics: Find column in top 30 rows with the most non-numeric text values
    if (autoColIdx === -1) {
      const colNonNumericCounts: { [key: number]: number } = {};
      
      rows.slice(0, 30).forEach(row => {
        if (!Array.isArray(row)) return;
        row.forEach((val, idx) => {
          if (val !== undefined && val !== null) {
            const strVal = String(val).trim();
            if (strVal && isNaN(Number(strVal)) && strVal.length > 2) {
              colNonNumericCounts[idx] = (colNonNumericCounts[idx] || 0) + 1;
            }
          }
        });
      });

      let maxCount = -1;
      let selectedCol = 0;
      Object.keys(colNonNumericCounts).forEach(key => {
        const idx = Number(key);
        if (colNonNumericCounts[idx] > maxCount) {
          maxCount = colNonNumericCounts[idx];
          selectedCol = idx;
        }
      });
      autoColIdx = selectedCol;
    }

    setSelectedColIdx(autoColIdx);
    setHeaderRowIdx(autoHeaderRow);

    // Initial student mapping
    const finalStudents = getStudentsFromRowsAndColumn(rows, autoColIdx, autoHeaderRow);
    setParsedStudents(finalStudents);
    return finalStudents;
  };

  const parseExcelLocal = async (file: File): Promise<ClassListEntry[]> => {
    const arrayBuffer = await file.arrayBuffer();
    const data = new Uint8Array(arrayBuffer);
    const workbook = XLSX.read(data, { type: 'array' });
    setWorkbookInstance(workbook);
    setExcelSheets(workbook.SheetNames);

    // Filter sheets to find the one with the maximum rows
    let bestSheetName = workbook.SheetNames[0];
    let maxRowsFound = 0;
    workbook.SheetNames.forEach(sheetName => {
      const worksheet = workbook.Sheets[sheetName];
      const rows = XLSX.utils.sheet_to_json<unknown[]>(worksheet, { header: 1 });
      if (rows.length > maxRowsFound) {
        maxRowsFound = rows.length;
        bestSheetName = sheetName;
      }
    });

    setSelectedSheetName(bestSheetName);
    return processExcelSheet(workbook, bestSheetName);
  };

  const handleColumnIndexChange = (colIdx: number) => {
    setSelectedColIdx(colIdx);
    if (excelRows.length > 0) {
      const students = getStudentsFromRowsAndColumn(excelRows, colIdx, headerRowIdx);
      setParsedStudents(students);
    }
  };

  const parseFile = async (currentFile: File) => {
    setIsParsing(true);
    setError(null);
    try {
      const ext = currentFile.name.split('.').pop()?.toLowerCase();
      
      if (ext === 'xlsx' || ext === 'xls') {
        const result = await parseExcelLocal(currentFile);
        if (result.length > 0) {
          onConfirm(result);
          onClose();
        } else {
          throw new Error("Could not extract any student names from the Excel file.");
        }
      } else if (ext === 'docx') {
        const result = await parseWordDocLocal(currentFile);
        if (result.length === 0) {
           throw new Error("Could not parse student strings. Ensure the Word document has a list of names.");
        }
        setParsedStudents(result);
        onConfirm(result);
        onClose();
      } else if (ext === 'pdf' || ext === 'doc' || ['jpg', 'png', 'jpeg'].includes(ext || '')) {
         if (!isOnline) {
           throw new Error(`Parsing .${ext} files offline is not supported. Please connect to the internet, or copy & paste text directly.`);
         }

          const base64 = await fileToBase64(currentFile);
          let mimeType = currentFile.type;
          if (!mimeType) {
            if (ext === 'pdf') mimeType = 'application/pdf';
            else if (ext === 'doc') mimeType = 'application/msword';
            else mimeType = 'image/jpeg';
          }

          const response = await fetch('/api/parse-class-list', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ fileData: base64, mimeType })
          });

          if (!response.ok) {
            const errData = await response.json();
            throw new Error(errData.error || "Failed to parse document via Gemini AI");
          }

          interface ParsedStudentItem {
            student?: string | number;
            studentName?: string | number;
            student_name?: string | number;
            name?: string | number;
            studentId?: string | number;
            studentIdOrName?: string | number;
            Name?: string | number;
            position?: number | string;
            pos?: number | string;
            sn?: number | string;
            id?: number | string;
            no?: number | string;
            "s/n"?: number | string;
          }

          const parsed = await response.json();
          if (Array.isArray(parsed) && parsed.length > 0) {
            const mapped = (parsed as ParsedStudentItem[]).map((item, idx) => {
              const studentName = item.student ?? item.studentName ?? item.student_name ?? item.name ?? item.studentId ?? item.studentIdOrName ?? item.Name ?? '';
              const positionVal = item.position ?? item.pos ?? item.sn ?? item.id ?? item.no ?? item["s/n"];
              return {
                position: parseInt(String(positionVal), 10) || (idx + 1),
                student: String(studentName).trim()
              };
            }).filter(item => item.student);

            setParsedStudents(mapped);
            onConfirm(mapped);
            onClose();
          } else {
            throw new Error("The file upload succeeded, but no student records were found.");
          }
      } else {
        throw new Error("Unsupported format. Supported files are Excel (.xlsx, .xls), Word (.docx, .doc), PDF, or Images.");
      }
    } catch (err: unknown) {
      console.error("Parsing failed", err);
      setError((err instanceof Error ? err.message : '') || "Could not read the file. Click help or try copy & pasting instead.");
      setParsedStudents([]);
    } finally {
      setIsParsing(false);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const selectedFile = e.target.files[0];
      setFile(selectedFile);
      parseFile(selectedFile);
    }
  };

  const handlePasteTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const text = e.target.value;
    setPastedText(text);

    if (!text.trim()) {
      setParsedStudents([]);
      return;
    }

    const lines = text.split('\n');
    const students: ClassListEntry[] = [];
    let currentPosition = 1;

    for (let line of lines) {
      line = line.trim();
      if (!line) continue;
      
      let studentName = line;
      let pos = currentPosition;
      
      // Look for SNs prefix like: "1. Dickson", "2) Amina"
      const numberPrefixMatch = line.match(/^(\d+)[\s.)\-_/:\\]+(.*)$/);
      if (numberPrefixMatch) {
        pos = parseInt(numberPrefixMatch[1], 10);
        studentName = numberPrefixMatch[2].trim();
      }

      const lower = studentName.toLowerCase();
      if (
        lower === 'student name' || 
        lower === 'name' || 
        lower === 'registration number' || 
        lower === 'reg no' || 
        lower === 'student' || 
        lower === 'class list' || 
        lower === 'names' ||
        lower === 'jina' ||
        lower === 'mwanafunzi'
      ) {
        continue;
      }

      if (studentName) {
        students.push({
          position: pos,
          student: studentName
        });
        currentPosition = Math.max(currentPosition, pos) + 1;
      }
    }

    // Always map cleanly to incremental position numbers (1,2,3... to avoid gaps)
    const normalized = students.map((s, idx) => ({
      position: idx + 1,
      student: s.student
    }));
    setParsedStudents(normalized);
  };

  const loadDemoList = () => {
    setParsedStudents(DEMO_CLASS_LIST);
    setError(null);
  };

  const triggerConfirm = () => {
    if (parsedStudents.length === 0) return;
    onConfirm(parsedStudents);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto" id="upload-class-list-container">
      <div className="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
        <div className="fixed inset-0 transition-opacity bg-black/60 backdrop-blur-sm" onClick={onClose} />

        <span className="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div className="inline-block w-full max-w-2xl overflow-hidden text-left align-middle transition-all transform bg-white dark:bg-gray-800 rounded-2xl shadow-xl border border-gray-100 dark:border-gray-700">
          <div className="px-6 py-4 bg-gray-50 dark:bg-gray-800/80 border-b border-gray-100 dark:border-gray-700 flex justify-between items-center">
            <div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Configure Class List</h3>
              <p className="text-xs text-gray-500 dark:text-gray-400">Add student names or registration lists to map sequential voice calls</p>
            </div>
            <button onClick={onClose} className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
              <CloseIcon className="w-6 h-6" />
            </button>
          </div>

          <div className="p-6 space-y-6">
            
            {/* Tabs Bar */}
            <div className="flex border-b border-gray-200 dark:border-gray-700">
              <button
                type="button"
                onClick={() => { setActiveTab('upload'); setError(null); }}
                className={`flex-1 pb-3 text-xs font-bold border-b-2 transition-all flex items-center justify-center gap-2 cursor-pointer ${
                  activeTab === 'upload' 
                    ? 'border-blue-900 text-blue-900 dark:border-blue-400 dark:text-blue-400' 
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                <FileSpreadsheet className="w-4 h-4 text-blue-900 dark:text-blue-400" />
                Upload File (.xlsx, .docx, .pdf)
              </button>
              <button
                type="button"
                onClick={() => { setActiveTab('paste'); setError(null); }}
                className={`flex-1 pb-3 text-xs font-bold border-b-2 transition-all flex items-center justify-center gap-2 cursor-pointer ${
                  activeTab === 'paste' 
                    ? 'border-blue-900 text-blue-900 dark:border-blue-400 dark:text-blue-400' 
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                <Clipboard className="w-4 h-4 text-teal-600" />
                Copy & Paste Text List
              </button>
              <button
                type="button"
                onClick={() => { setActiveTab('demo'); setError(null); }}
                className={`flex-1 pb-3 text-xs font-bold border-b-2 transition-all flex items-center justify-center gap-2 cursor-pointer ${
                  activeTab === 'demo' 
                    ? 'border-blue-900 text-blue-900 dark:border-blue-400 dark:text-blue-400' 
                    : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                <Sparkles className="w-4 h-4 animate-pulse text-amber-500" />
                Try Demo List (Instant)
              </button>
            </div>

            {/* TAB CONTENT: FILE UPLOAD */}
            {activeTab === 'upload' && (
              <div className="space-y-4">
                {!isOnline && parsedStudents.length === 0 && (
                  <div className="bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/50 text-amber-800 dark:text-amber-400 text-xs px-3 py-2 rounded-xl flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-amber-500 animate-pulse" />
                    <span>Offline Mode: Only Local Excel (.xlsx) and Word (.docx) formats can be parsed.</span>
                  </div>
                )}

                <div className="relative border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-xl p-8 text-center hover:border-blue-900 dark:hover:border-blue-400 transition-all bg-gray-50 dark:bg-gray-900/40 cursor-pointer">
                  <input
                    type="file"
                    accept=".xlsx,.xls,.doc,.docx,.pdf,image/png,image/jpeg,image/jpg"
                    onChange={handleFileChange}
                    className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
                  />
                  <CloudIcon className="w-12 h-12 mx-auto text-gray-400 dark:text-gray-500" />
                  <p className="mt-2 text-sm font-bold text-gray-700 dark:text-gray-300">
                    {file ? file.name : "Choose a file or drag & drop"}
                  </p>
                  <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                    Excel Spreadsheet (.xlsx, .xls), PDF, Word document, or Image
                  </p>
                </div>

                {/* Optional Sheet selector if workbook has multiple sheets */}
                {excelSheets.length > 1 && workbookInstance && (
                  <div className="bg-amber-50/50 dark:bg-amber-950/15 border border-amber-200/50 dark:border-amber-900/40 p-4 rounded-xl space-y-2">
                    <div className="flex items-center gap-1.5 text-amber-800 dark:text-amber-300">
                      <AlertCircle className="w-4 h-4" />
                      <label className="text-xs font-bold uppercase tracking-wide">
                        📝 Multiple Excel Sheets Detected! Select active Worksheet:
                      </label>
                    </div>
                    <select
                      value={selectedSheetName}
                      onChange={(e) => {
                        const name = e.target.value;
                        setSelectedSheetName(name);
                        if (workbookInstance) {
                          processExcelSheet(workbookInstance, name);
                        }
                      }}
                      className="w-full text-xs font-semibold bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg p-2.5 shadow-sm text-gray-750 dark:text-gray-250 outline-none"
                    >
                      {excelSheets.map(name => (
                        <option key={name} value={name}>
                          {name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {/* Optional Column selector dropdown for multi-column Excel */}
                {excelColumns.length > 1 && (
                  <div className="bg-blue-50/55 dark:bg-blue-950/15 border border-blue-200/50 dark:border-blue-900/40 p-4 rounded-xl space-y-2">
                    <div className="flex items-center gap-1.5 text-blue-900 dark:text-blue-300">
                      <CheckCircle2 className="w-4 h-4 text-teal-650" />
                      <label className="text-xs font-bold uppercase tracking-wide">
                        🎯 Select Name / Registration Number Column:
                      </label>
                    </div>
                    <select
                      value={selectedColIdx}
                      onChange={(e) => handleColumnIndexChange(Number(e.target.value))}
                      className="w-full text-xs font-bold bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg p-3 shadow-md text-teal-800 dark:text-teal-300 focus:ring-1 focus:ring-teal-500 outline-none"
                    >
                      {excelColumns.map((col) => (
                        <option key={col.index} value={col.index}>
                          {col.label} — Preview: {col.preview || '(empty values)'}
                        </option>
                      ))}
                    </select>
                    <p className="text-[10px] text-gray-500 dark:text-gray-400 italic">
                      Can't find student names? Toggle through the columns above to find the correct student registry!
                    </p>
                  </div>
                )}
              </div>
            )}

            {/* TAB CONTENT: COPY & PASTE LIST */}
            {activeTab === 'paste' && (
              <div className="space-y-4 text-left">
                <div className="bg-teal-50/50 dark:bg-teal-950/10 border border-teal-100 dark:border-teal-900/50 p-4 rounded-xl space-y-1">
                  <h4 className="text-xs font-bold text-teal-900 dark:text-teal-400 uppercase tracking-wider flex items-center gap-1">
                    <Clipboard className="w-3.5 h-3.5" /> No file? Paste Roster Easily!
                  </h4>
                  <p className="text-xs text-gray-650 dark:text-gray-450 leading-relaxed font-medium">
                    Copy names directly from WhatsApp, PDF, an email, or text rows and paste them below. <strong>Enter one name or registration ID per row</strong>. Serial numbers are automatically parsed & handled!
                  </p>
                </div>

                <div className="space-y-1.5 text-left">
                  <span className="text-xs font-extrabold text-gray-400 block uppercase">Student Registry Field:</span>
                  <textarea
                    rows={6}
                    value={pastedText}
                    onChange={handlePasteTextChange}
                    placeholder={`Paste student names here, one per line e.g.\n1. Amina Juma Hassan\n2. Dickson Michael Chaula\n3. Emmanuel Peter Mwambene`}
                    className="w-full text-xs font-semibold font-mono p-3.5 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 rounded-xl placeholder-gray-400 text-gray-800 dark:text-gray-200 focus:ring-1 focus:ring-teal-550 outline-none leading-relaxed"
                  />
                </div>

                {parsedStudents.length > 0 && (
                  <div className="bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-950/20 dark:to-emerald-950/20 border border-teal-100 dark:border-teal-900/40 p-4 rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-4 mt-2">
                    <div className="space-y-0.5">
                      <h5 className="text-xs font-extrabold text-teal-900 dark:text-teal-300 uppercase tracking-wider">Ready to add {parsedStudents.length} Students in order</h5>
                      <p className="text-[11px] text-gray-655 dark:text-gray-400 font-medium">Click below to load this sequence into your session and proceed to Voice grading entries.</p>
                    </div>
                    <button
                      onClick={triggerConfirm}
                      className="w-full md:w-auto px-5 py-2.5 bg-teal-600 hover:bg-teal-700 text-white text-xs font-extrabold rounded-xl transition-all active:scale-[0.98] shadow-md hover:shadow-teal-600/10 flex items-center justify-center gap-1.5 cursor-pointer whitespace-nowrap"
                    >
                      Confirm & Start Voice Entries →
                    </button>
                  </div>
                )}
              </div>
            )}

            {/* TAB CONTENT: TRY DEMO INSTANTLY */}
            {activeTab === 'demo' && (
              <div className="space-y-5 text-left border border-amber-200/60 dark:border-amber-900/30 bg-amber-50/15 dark:bg-amber-950/5 p-6 rounded-2xl">
                <div className="flex items-start space-x-3">
                  <div className="p-2 bg-amber-500/10 text-amber-500 rounded-xl">
                    <Sparkles className="w-6 h-6 animate-pulse" />
                  </div>
                  <div>
                    <h4 className="text-sm font-extrabold text-teal-800 dark:text-teal-400">
                      ⚡ Speed-Test Mode (Hands-Free Swahili Guide)
                    </h4>
                    <p className="text-xs text-gray-600 dark:text-gray-400 mt-1 leading-relaxed font-semibold">
                      Immediately load a professional classroom list of 15 student names (e.g., <em>Amina Juma Hassan</em>, <em>Dickson Michael Chaula</em>) to test the Hands-free Automatic Voice Assistant instantly without needing to configure files or text!
                    </p>
                  </div>
                </div>

                <div className="bg-white dark:bg-gray-800/80 p-4 border border-gray-150 dark:border-gray-700/60 rounded-xl space-y-2">
                  <span className="text-[10px] font-black tracking-widest text-gray-400 uppercase">Class Roster Preview:</span>
                  <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-[11px] text-gray-600 dark:text-gray-400 font-mono font-medium">
                    <div>1. Amina Juma Hassan</div>
                    <div>2. Dickson Michael Chaula</div>
                    <div>3. Emmanuel Peter...</div>
                    <div>4. Faraja Said Kiluvya</div>
                    <div>5. Grace John Masanje</div>
                    <div>6. Hamisi Selemani Bagari ...</div>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={loadDemoList}
                  className="w-full flex items-center justify-center gap-2 py-3 px-4 bg-teal-600 hover:bg-teal-700 text-white font-extrabold text-xs tracking-wide rounded-xl shadow-lg transition-transform active:scale-[0.98] cursor-pointer"
                >
                  <Sparkles className="w-4 h-4 text-amber-300 fill-amber-300" />
                  Load 15-Student Demo List Now
                </button>
              </div>
            )}

            {error && (
              <div className="p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-800 dark:text-red-300 text-sm rounded-xl">
                {error}
              </div>
            )}

            {isParsing && (
              <div className="flex items-center justify-center py-8 space-x-3">
                <span className="animate-spin text-blue-900 dark:text-blue-400">
                  <Spinner size="md" />
                </span>
                <span className="text-sm font-semibold text-gray-600 dark:text-gray-400">Analyzing list contents...</span>
              </div>
            )}

            {!isParsing && parsedStudents.length > 0 && activeTab === 'upload' && (
              <div className="space-y-4 text-left pt-2 border-t border-gray-100 dark:border-gray-700">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-extrabold text-gray-700 dark:text-gray-300 uppercase tracking-wide flex items-center gap-1.5">
                    <CheckCircle2 className="w-4 h-4 text-teal-650" />
                    Students Loaded ({parsedStudents.length} Students)
                  </span>
                  <button 
                    onClick={() => { setParsedStudents([]); setFile(null); setPastedText(''); }}
                    className="text-xs text-red-650 dark:text-red-400 font-bold flex items-center gap-1 hover:underline cursor-pointer"
                  >
                    <Trash2 className="w-3.5 h-3.5" /> Start Over / Upload Another
                  </button>
                </div>

                <div className="border border-gray-200 dark:border-gray-700 rounded-xl max-h-40 overflow-y-auto divide-y divide-gray-100 dark:divide-gray-750 custom-scrollbar bg-gray-50/50 dark:bg-gray-900/20 shadow-inner">
                  {parsedStudents.map((item) => (
                    <div key={item.position} className="flex items-center px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700/50 transition-colors">
                      <span className="w-10 text-xs font-mono font-black text-teal-600 bg-teal-50 dark:bg-teal-950/30 px-1 rounded-sm text-center mr-3">{item.position}</span>
                      <span className="text-xs font-semibold text-gray-800 dark:text-gray-200 truncate">{item.student}</span>
                    </div>
                  ))}
                </div>

                <div className="bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-950/20 dark:to-emerald-950/20 border border-teal-100 dark:border-teal-900/40 p-4 rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-4 mt-2">
                  <div className="space-y-0.5">
                    <h5 className="text-xs font-extrabold text-teal-900 dark:text-teal-305 uppercase tracking-wider">Ready to add {parsedStudents.length} Students in order</h5>
                    <p className="text-[11px] text-gray-650 dark:text-gray-400 font-medium">Click below to load this sequence into your session and proceed to Voice grading entries.</p>
                  </div>
                  <button
                    onClick={triggerConfirm}
                    className="w-full md:w-auto px-5 py-2.5 bg-teal-600 hover:bg-teal-700 text-white text-xs font-extrabold rounded-xl transition-all active:scale-[0.98] shadow-md hover:shadow-teal-600/10 flex items-center justify-center gap-1.5 cursor-pointer whitespace-nowrap"
                  >
                    Confirm & Start Voice Entries →
                  </button>
                </div>
              </div>
            )}
          </div>

          <div className="px-6 py-4 bg-gray-50 dark:bg-gray-800/80 border-t border-gray-100 dark:border-gray-700 flex justify-end gap-3 rounded-b-2xl">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm font-bold text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 rounded-xl transition-all active:scale-95 cursor-pointer"
            >
              Cancel
            </button>
            <button
              disabled={parsedStudents.length === 0}
              onClick={triggerConfirm}
              className="px-6 py-2 text-sm font-bold text-white bg-blue-900 dark:bg-blue-600 hover:bg-blue-800 dark:hover:bg-blue-500 rounded-xl transition-all disabled:opacity-40 disabled:cursor-not-allowed active:scale-95 shadow-lg shadow-blue-900/10 cursor-pointer"
            >
              Confirm & Start Voice Entries
            </button>
          </div>      </div>
        </div>
      </div>
  );
};
