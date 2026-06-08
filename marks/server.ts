import express from "express";
import { createServer as createViteServer } from "vite";
import path from "path";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI, Type } from "@google/genai";

async function startServer() {
  const app = express();
  const PORT = 3000;

  const anthropic = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
  });

  const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY,
    httpOptions: {
      headers: {
        'User-Agent': 'aistudio-build',
      }
    }
  });

  // Middleware for parsing JSON and URL-encoded bodies with a larger limit
  app.use(express.json({ limit: '100mb' }));
  app.use(express.urlencoded({ limit: '100mb', extended: true }));

  // Claude OCR endpoint
  app.post("/api/extract-marks/claude", async (req, res) => {
    try {
      const { images, maxMark } = req.body;
      
      if (!process.env.ANTHROPIC_API_KEY) {
        return res.status(500).json({ error: "ANTHROPIC_API_KEY is not configured on the server." });
      }

      const results = [];

      for (const imageData of images) {
        const response = await anthropic.messages.create({
          model: "claude-3-5-sonnet-latest",
          max_tokens: 1024,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "image",
                  source: {
                    type: "base64",
                    media_type: "image/jpeg",
                    data: imageData,
                  },
                },
                {
                  type: "text",
                  text: `Extract student ID and marks from this image. 
- Identity: Extract Student ID or Name.
- Max mark allowed is ${maxMark}. 
- IMPORTANT: If a mark exceeds ${maxMark}, do not return a mark for that student (set it to null or omit the mark field).
- Return ONLY a JSON array: [{"studentId": "...", "mark": number | null}]. No other text.`
                }
              ],
            },
          ],
        });

        const content = response.content[0];
        if (content.type === 'text') {
           try {
             const cleaned = content.text.replace(/```json|```/g, "").trim();
             const parsed = JSON.parse(cleaned);
             if (Array.isArray(parsed)) {
                results.push(...parsed.map((item: Record<string, unknown>) => ({
                    studentId: String(item.studentId || ""),
                    mark: (typeof item.mark === 'number' && item.mark <= maxMark) ? item.mark : null
                })));
             }
           } catch {
             console.error("Failed to parse Claude output:", content.text);
           }
        }
      }

      res.json(results);
    } catch (err: unknown) {
      console.error("Claude API Error:", err);
      // Check for specific Anthropic error types or messages
      const errorObj = err as Record<string, unknown>; 
      const innerError = errorObj?.error as Record<string, unknown> | undefined;
      const errorMessage = innerError?.message || errorObj?.message || "Failed to process with Claude";
      
      if (typeof errorMessage === 'string' && (errorMessage.includes("credit balance is too low") || errorMessage.includes("insufficient_funds"))) {
          return res.status(402).json({ error: "Your Anthropic (Claude) credit balance is too low. Please purchase more credits in your Anthropic Dashboard." });
      }
      
      if (errorObj?.status === 429) {
          return res.status(429).json({ error: "Claude AI is currently experiencing high demand. Please try again in a few moments." });
      }

      res.status(500).json({ error: typeof errorMessage === 'string' ? errorMessage : "Failed to process with Claude" });
    }
  });

  // Gemini OCR endpoint
  app.post("/api/extract-marks/gemini", async (req, res) => {
    try {
      const { image, mimeType, maxMark } = req.body;
      
      if (!process.env.GEMINI_API_KEY) {
        return res.status(500).json({ error: "GEMINI_API_KEY is not configured on the server." });
      }

      if (!image) {
        return res.status(400).json({ error: "Image data is required" });
      }

      const prompt = `OCR Task: Extract records from Mark Sheet or Assignment. 
- Identity Priority: Extract Student ID if present; if not, use the Student Name as studentId.
- Context: Find marks located in tables (mark sheets) or top corners/stamps (assignments).
- Max mark allowed is ${maxMark}. If a mark exceeds this, set it to null.
- Output: Exact JSON array ONLY.`;

      const response = await ai.models.generateContent({
        model: "gemini-3.5-flash",
        contents: [
          { text: prompt },
          {
            inlineData: {
              data: image,
              mimeType: mimeType || "image/jpeg",
            }
          }
        ],
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                studentId: { type: Type.STRING },
                mark: { type: Type.NUMBER, nullable: true },
              },
              required: ["studentId", "mark"],
            },
          },
          temperature: 0,
        },
      });

      const text = response.text;
      if (!text) {
        throw new Error("Empty response from Gemini");
      }

      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        const cleaned = parsed.map((item: { studentId?: string; mark?: number | null }) => ({
          studentId: item.studentId || '',
          mark: (typeof item.mark === 'number' && item.mark >= 0 && item.mark <= maxMark) ? item.mark : null,
        })).filter(item => item.studentId);
        return res.json(cleaned);
      }

      res.json([]);
    } catch (err: unknown) {
      console.error("Gemini API Error:", err);
      const errorObj = err as Record<string, unknown>;
      const errorMessage = errorObj?.message || "Failed to process with Gemini";
      
      if (errorObj?.status === 429 || errorObj?.code === 429 || (typeof errorMessage === 'string' && (errorMessage.includes("429") || errorMessage.includes("RESOURCE_EXHAUSTED")))) {
        return res.status(429).json({ error: "Gemini AI is currently experiencing high demand. Please try again in a few moments." });
      }

      res.status(500).json({ error: typeof errorMessage === 'string' ? errorMessage : "Failed to process with Gemini" });
    }
  });

  // Parse class list from documents via Gemini multimodal feature
  app.post("/api/parse-class-list", async (req, res) => {
    try {
      const { fileData, mimeType } = req.body;
      if (!process.env.GEMINI_API_KEY) {
        return res.status(500).json({ error: "GEMINI_API_KEY is not configured on the server." });
      }
      if (!fileData) {
        return res.status(400).json({ error: "File data is required" });
      }

      const prompt = `This is a student class list. Extract all student names or registration numbers in the exact order they appear. Return only a JSON array where each item has position as integer starting from 1 and student as string containing the name or registration number. Preserve the exact order. Do not add or remove any entries.`;

      const response = await ai.models.generateContent({
        model: "gemini-3.5-flash",
        contents: [
          { text: prompt },
          {
            inlineData: {
              data: fileData,
              mimeType: mimeType || "application/pdf"
            }
          }
        ],
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                position: { type: Type.INTEGER },
                student: { type: Type.STRING }
              },
              required: ["position", "student"]
            }
          },
          temperature: 0
        }
      });

      const text = response.text;
      if (!text) {
        throw new Error("Empty response from Gemini");
      }

      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        return res.json(parsed);
      }
      res.json([]);
    } catch (err: unknown) {
      console.error("Parse Class List Error:", err);
      const errorMessage = (err as Error)?.message || "Failed to parse class list via Gemini";
      res.status(500).json({ error: errorMessage });
    }
  });

  // Extract student position and mark pairs from ambiguous transcription via Gemini
  app.post("/api/extract-marks-voice", async (req, res) => {
    try {
      const { text: transcribedText } = req.body;
      if (!process.env.GEMINI_API_KEY) {
        return res.status(500).json({ error: "GEMINI_API_KEY is not configured on the server." });
      }
      if (!transcribedText) {
        return res.status(400).json({ error: "Transcription is empty" });
      }

      const prompt = `A school teacher is assigning student marks by voice in a mix of Swahili and English. Extract all student position and mark pairs from this text: "${transcribedText}"
Positions are identified by phrases like namba moja, number one, namba 5 etc. Marks are the numbers after words like amepata, has, got, scored, ana, ni.
Return only a JSON array: 
[{"position": integer, "mark": number}]
Maximum 5 pairs. If unclear return empty array.`;

      const response = await ai.models.generateContent({
        model: "gemini-3.5-flash",
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                position: { type: Type.INTEGER },
                mark: { type: Type.NUMBER, nullable: true }
              },
              required: ["position", "mark"]
            }
          },
          temperature: 0
        }
      });

      const text = response.text;
      if (!text) {
        throw new Error("Empty response from Gemini");
      }

      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        return res.json(parsed);
      }
      res.json([]);
    } catch (err: unknown) {
      console.error("Voice extract error:", err);
      const errorMessage = (err as Error)?.message || "Failed to process voice transcription with Gemini";
      res.status(500).json({ error: errorMessage });
    }
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*all', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
