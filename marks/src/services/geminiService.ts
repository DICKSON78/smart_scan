import { StudentMark } from '../types';

/**
 * Resizes a base64 image to a maximum dimension to speed up processing.
 */
const resizeImage = async (base64: string, mimeType: string, maxDimension: number = 640): Promise<string> => {
    if (!base64) throw new Error("Empty image data provided to resizeImage");
    
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => {
            try {
                let width = img.width;
                let height = img.height;

                if (width === 0 || height === 0) {
                    throw new Error("Image has zero dimensions");
                }

                if (width > height) {
                    if (width > maxDimension) {
                        height *= maxDimension / width;
                        width = maxDimension;
                    }
                } else {
                    if (height > maxDimension) {
                        width *= maxDimension / height;
                        height = maxDimension;
                    }
                }

                const canvas = document.createElement('canvas');
                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d');
                if (!ctx) throw new Error("Could not get canvas context");
                
                ctx.drawImage(img, 0, 0, width, height);
                
                // Maximum compression for extreme speed
                const dataUrl = canvas.toDataURL(mimeType || 'image/jpeg', 0.2);
                const parts = dataUrl.split(',');
                if (parts.length < 2) throw new Error("Failed to generate base64 from canvas");
                
                resolve(parts[1]);
            } catch (err) {
                reject(err);
            }
        };
        img.onerror = () => reject(new Error("Failed to load image for resizing."));
        
        let cleanBase64 = base64.trim().replace(/\s/g, '');
        if (cleanBase64.startsWith('data:')) {
            const commaIndex = cleanBase64.indexOf(',');
            if (commaIndex !== -1) {
                cleanBase64 = cleanBase64.substring(commaIndex + 1);
            }
        }
        
        img.src = `data:${mimeType || 'image/jpeg'};base64,${cleanBase64}`;
    });
};

const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export const extractMarksFromImage = async (
    base64Image: string, 
    mimeType: string, 
    maxMark: number,
    retryCount: number = 0
): Promise<Omit<StudentMark, 'id'>[]> => {
    const MAX_RETRIES = 3;
    
    try {
        const optimizedBase64 = await resizeImage(base64Image, mimeType);
        
        const response = await fetch('/api/extract-marks/gemini', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                image: optimizedBase64,
                mimeType,
                maxMark,
            }),
        });

        if (!response.ok) {
            // Handle HTTP status errors (e.g., 429)
            if (response.status === 429) {
                if (retryCount < MAX_RETRIES) {
                    const waitTime = Math.pow(2, retryCount) * 1000 + Math.random() * 1000;
                    console.warn(`Gemini busy (429). Retrying in ${Math.round(waitTime)}ms... (Attempt ${retryCount + 1}/${MAX_RETRIES})`);
                    await delay(waitTime);
                    return extractMarksFromImage(base64Image, mimeType, maxMark, retryCount + 1);
                }
                throw new Error("The Gemini model is currently experiencing extremely high demand. Please try again in a few minutes, or switch to the Claude AI or PaddleOCR engine in Settings.");
            }
            
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to process with Gemini');
        }

        return await response.json();

    } catch (error: unknown) {
        let isRetryable = false;
        let errorMessage = "Extraction failed";

        if (error instanceof Error) {
            errorMessage = error.message;
            isRetryable = errorMessage.includes('429') || errorMessage.includes('RESOURCE_EXHAUSTED');
        }
        
        if (isRetryable && retryCount < MAX_RETRIES) {
            const waitTime = Math.pow(2, retryCount) * 1000 + Math.random() * 1000;
            console.warn(`Gemini busy (429/Error). Retrying in ${Math.round(waitTime)}ms... (Attempt ${retryCount + 1}/${MAX_RETRIES})`);
            await delay(waitTime);
            return extractMarksFromImage(base64Image, mimeType, maxMark, retryCount + 1);
        }

        console.error("Error calling Gemini API:", error);
        throw error;
    }
};
