
export type OcrEngine = 'gemini' | 'claude' | 'paddle';

export interface AuditEntry {
  id: string;
  timestamp: string;
  action: 'EXTRACT' | 'EDIT' | 'DELETE' | 'CREATE_SESSION';
  details: string;
  studentId?: string;
  oldValue?: string | number | null;
  newValue?: string | number | null;
}

export interface StudentMark {
  id: string; // A unique ID for React key props and state updates
  studentId: string;
  mark: number | null; // Allow null if a mark is not found or invalid
  source?: 'scan' | 'voice' | 'manual';
}

export interface ClassListEntry {
  position: number;
  student: string;
  mark?: number | null;
}

export interface Session {
  id: string;
  name: string;
  maxMark: number;
  marks: StudentMark[];
  logs: AuditEntry[];
  createdAt: string; // ISO String for date
  classList?: ClassListEntry[];
}
