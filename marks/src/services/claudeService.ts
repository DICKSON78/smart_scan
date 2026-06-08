import { StudentMark } from '../types';

export const extractMarksWithClaude = async (
    images: { data: string; mimeType: string }[],
    maxMark: number
): Promise<Omit<StudentMark, 'id'>[]> => {
    try {
        const response = await fetch('/api/extract-marks/claude', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                images: images.map(img => img.data),
                maxMark,
            }),
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to process with Claude');
        }

        return await response.json();
    } catch (error) {
        console.error("Claude Service Error:", error);
        throw error;
    }
};
