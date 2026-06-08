
import * as ocr from '@paddlejs-models/ocr';
import '@paddlejs/paddlejs-backend-webgl';
import { StudentMark } from '../types';

let isInitialized = false;

export const initPaddleOCR = async () => {
    if (isInitialized) return;
    try {
        await ocr.init();
        isInitialized = true;
        console.log("PaddleOCR initialized successfully");
    } catch (error) {
        console.error("Failed to initialize PaddleOCR:", error);
        throw new Error("Failed to initialize PaddleOCR. Please check your internet connection for the first load.");
    }
};

const parseTextResults = (results: string[], maxMark: number): Omit<StudentMark, 'id'>[] => {
    if (!results || results.length === 0) return [];

    const marks: Omit<StudentMark, 'id'>[] = [];
    let topMark: number | null = null;
    let topMarkIndex = -1;

    // 1. Identify a prominent mark at the top (first 3 lines)
    for (let i = 0; i < Math.min(results.length, 3); i++) {
        const text = results[i].trim();
        // Look for something like "8.5", "8/10", or just "8"
        const cleanText = text.split('/')[0].trim();
        const num = parseFloat(cleanText);
        
        if (!isNaN(num) && num >= 0 && num <= maxMark) {
            // Check if it looks like a standalone mark (short string)
            if (text.length <= 6) {
                topMark = num;
                topMarkIndex = i;
                break;
            }
        }
    }

    // 2. Process all lines
    results.forEach((line, index) => {
        // Skip the line if it was identified as the top mark
        if (index === topMarkIndex) return;

        const trimmedLine = line.trim();
        if (!trimmedLine || trimmedLine.length < 2) return;

        const parts = trimmedLine.split(/\s+/);
        let studentId = "";
        let mark: number | null = null;

        // Try to find a mark at the end of the line (e.g., "John Doe 8.5")
        const lastPart = parts[parts.length - 1];
        const lastNum = parseFloat(lastPart.split('/')[0]);
        
        let idParts = parts;
        if (parts.length > 1 && !isNaN(lastNum) && lastNum >= 0 && lastNum <= maxMark && lastPart.length <= 5) {
            mark = lastNum;
            idParts = parts.slice(0, -1);
        } else {
            // No mark at end or exceeds maxMark, check if we can use the topMark
            mark = (topMark !== null && topMark <= maxMark) ? topMark : null;
        }

        // Prioritize Registration Number within the remaining parts
        // Heuristic: A registration number often contains both letters and numbers, or is a specific length
        let foundRegNo = "";
        const nameParts: string[] = [];

        idParts.forEach(part => {
            const hasLetter = /[a-zA-Z]/.test(part);
            const hasDigit = /\d/.test(part);
            const isLongNumeric = /^\d{5,}$/.test(part); // e.g. "123456"
            const isAlphanumeric = hasLetter && hasDigit; // e.g. "CS101"
            
            if ((isAlphanumeric || isLongNumeric) && !foundRegNo) {
                foundRegNo = part;
            } else {
                nameParts.push(part);
            }
        });

        studentId = foundRegNo || idParts.join(' ').trim();

        // Final validation: Ensure studentId isn't just a number (which might be a stray mark)
        const isPurelyNumeric = /^\d+(\.\d+)?$/.test(studentId.replace(/[/-]/g, ''));
        if (studentId && mark !== null && !isPurelyNumeric) {
            marks.push({ studentId, mark });
        }
    });

    return marks;
};

export const extractMarksFromImageWithPaddleOCR = async (
    base64Image: string,
    mimeType: string,
    maxMark: number
): Promise<Omit<StudentMark, 'id'>[]> => {
    try {
        await initPaddleOCR();
        
        const img = new Image();
        const imageLoadPromise = new Promise<HTMLImageElement>((resolve, reject) => {
            img.onload = () => resolve(img);
            img.onerror = reject;
        });
        
        let cleanBase64 = base64Image.trim().replace(/\s/g, '');
        if (!cleanBase64.startsWith('data:')) {
            cleanBase64 = `data:${mimeType || 'image/jpeg'};base64,${cleanBase64}`;
        }
        img.src = cleanBase64;
        
        const loadedImg = await imageLoadPromise;
        
        // PaddleOCR recognize returns an array of strings
        const res = await ocr.recognize(loadedImg);
        console.log("PaddleOCR raw results:", res);
        
        return parseTextResults(res, maxMark);
    } catch (error) {
        console.error("Error using PaddleOCR:", error);
        throw new Error("PaddleOCR failed to process the image. Ensure the image is clear and contains text.");
    }
};
