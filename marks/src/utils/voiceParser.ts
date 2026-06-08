const swahiliNumberMap: { [key: string]: number } = {
  'moja': 1, 'kwanza': 1,
  'mbili': 2, 'pili': 2,
  'tatu': 3,
  'nne': 4,
  'tano': 5,
  'sita': 6,
  'saba': 7,
  'nane': 8,
  'tisa': 9,
  'kumi': 10,
  'ishirini': 20,
  'thelathini': 30,
  'arobaini': 40,
  'hamsini': 50,
  'sitini': 60,
  'sabini': 70,
  'themanini': 80,
  'tisini': 90,
  'mia': 100
};

const englishNumberMap: { [key: string]: number } = {
  'one': 1, 'first': 1,
  'two': 2, 'second': 2,
  'three': 3, 'third': 3,
  'four': 4, 'fourth': 4,
  'five': 5, 'fifth': 5,
  'six': 6, 'sixth': 6,
  'seven': 7, 'seventh': 7,
  'eight': 8, 'eighth': 8,
  'nine': 9, 'ninth': 9,
  'ten': 10, 'tenth': 10,
  'eleven': 11, 'twelve': 12, 'twelfth': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
  'hundred': 100
};

export const parseSpokenNumber = (text: string): number | null => {
  const clean = text.toLowerCase().trim();
  if (!clean) return null;
  
  if (!isNaN(Number(clean))) {
    return Number(clean);
  }

  // Split digits by space or "na" / "and" or punctuation
  const words = clean.split(/[\s-]+/);
  let total = 0;
  let temp = 0;

  for (const rawWord of words) {
    const word = rawWord.replace(/[.,:;()?]/g, "").trim();
    if (!word || word === 'na' || word === 'and') continue;

    if (!isNaN(Number(word))) {
      temp += Number(word);
      continue;
    }

    const swNum = swahiliNumberMap[word];
    const enNum = englishNumberMap[word];
    const num = swNum !== undefined ? swNum : enNum;

    if (num !== undefined) {
      if (num === 100) {
        if (temp === 0) temp = 1;
        total += temp * 100;
        temp = 0;
      } else {
        temp += num;
      }
    }
  }
  total += temp;
  return total > 0 ? total : null;
};

interface ExtractedPair {
  position: number;
  mark: number | null;
}

export const ruleBasedVoiceParser = (text: string): ExtractedPair[] => {
  if (!text) return [];

  // Split sentence into segments by common separators
  // comma, the word "and", the word "na", full stop, the word "then", the word "kisha"
  const segments = text.split(/[,.]|\b(?:and|na|then|kisha)\b/gi);
  const pairs: ExtractedPair[] = [];

  const positionPrefixes = [
    'namba', 'nambari', 'wa kwanza', 'wa pili', 'wa tatu', 'wa nne', 'wa tano', 
    'number', 'student', 'position', 'the first', 'first', 'second', 'third', 'fourth', 'fifth'
  ];

  const markTriggers = [
    'amepata', 'anapata', 'ana', 'ni', 'alipata', 'kapata', 'amefaulu', 'marks',
    'has', 'got', 'scored', 'gets', 'received', 'is', 'points', 'has got', 'has scored'
  ];

  for (const rawSegment of segments) {
    const segment = rawSegment.trim();
    if (!segment) continue;

    const lowerSegment = segment.toLowerCase();

    // 1. Look for a position trigger and extract the position number
    let position: number | null = null;
    let posIndex = -1;
    let posLength = 0;

    // First try standard patterns, e.g., "namba 5" or "number 12"
    const numberDigitMatch = segment.match(/\b(?:number|namba|nambari|student)\s*(\d+)\b/i);
    if (numberDigitMatch) {
      position = parseInt(numberDigitMatch[1], 10);
      posIndex = segment.toLowerCase().indexOf(numberDigitMatch[0].toLowerCase());
      posLength = numberDigitMatch[0].length;
    } else {
      // Find position trigger words
      for (const prefix of positionPrefixes) {
        const idx = lowerSegment.indexOf(prefix);
        if (idx !== -1) {
          // Find if there is a number after it
          const afterPrefix = segment.substring(idx + prefix.length).trim();
          // Extract the first word or words
          const wordsAfter = afterPrefix.split(/\s+/);
          if (wordsAfter.length > 0) {
            // Try to parse the next word(s)
            // Let's try 1 word, then 2 words (e.g., "mia moja", "ishirini na tano")
            let parsedVal = parseSpokenNumber(wordsAfter[0]);
            let wordsTaken = 1;
            
            if (wordsAfter.length >= 3 && (wordsAfter[1].toLowerCase() === 'na' || wordsAfter[1].toLowerCase() === 'and')) {
              const parsedValCompound = parseSpokenNumber(wordsAfter.slice(0, 3).join(' '));
              if (parsedValCompound !== null) {
                parsedVal = parsedValCompound;
                wordsTaken = 3;
              }
            } else if (wordsAfter.length >= 2) {
              const parsedValTwo = parseSpokenNumber(wordsAfter.slice(0, 2).join(' '));
              if (parsedValTwo !== null) {
                parsedVal = parsedValTwo;
                wordsTaken = 2;
              }
            }

            if (parsedVal !== null) {
              position = parsedVal;
              posIndex = idx;
              posLength = prefix.length + wordsAfter.slice(0, wordsTaken).join(' ').length + 1;
              break;
            }
          }
        }
      }
    }

    // Heuristic: If no explicit position trigger text, but there are digits, let's look for "1 amepata 45"
    if (position === null) {
      const firstDigitMatch = segment.match(/\b(\d+)\b/);
      if (firstDigitMatch) {
        const parsedDigit = parseInt(firstDigitMatch[1], 10);
        // Let's check if there's a mark trigger following it
        const idxOfDigit = segment.indexOf(firstDigitMatch[1]);
        const textAfterDigit = segment.substring(idxOfDigit + firstDigitMatch[1].length).toLowerCase();
        const hasTriggerAfter = markTriggers.some(trigger => textAfterDigit.includes(trigger));
        if (hasTriggerAfter) {
          position = parsedDigit;
          posIndex = idxOfDigit;
          posLength = firstDigitMatch[1].length;
        }
      }
    }

    // If no position found, skip segment
    if (position === null || posIndex === -1) {
      continue;
    }

    // 2. Look for a mark trigger and extract the number that immediately follows it
    let mark: number | null = null;
    let markFound = false;
    const textAfterPos = segment.substring(posIndex + posLength).trim();

    for (const trigger of markTriggers) {
      const trigIdx = textAfterPos.toLowerCase().indexOf(trigger);
      if (trigIdx !== -1) {
        const textAfterTrigger = textAfterPos.substring(trigIdx + trigger.length).trim();
        const wordsAfter = textAfterTrigger.split(/\s+/);
        if (wordsAfter.length > 0) {
          // Parse number directly
          const parsedMark = parseSpokenNumber(wordsAfter[0]);
          if (parsedMark !== null) {
            mark = parsedMark;
            markFound = true;
            break;
          }
        }
      }
    }

    // 4. If position is found but no mark trigger found, look for any standalone number after the position as the mark
    if (!markFound) {
      const digitsAfter = textAfterPos.match(/\b(\d+)\b/);
      if (digitsAfter) {
        mark = parseInt(digitsAfter[1], 10);
      } else {
        // Try word numbers
        const wordsAfter = textAfterPos.split(/\s+/);
        for (let i = 0; i < wordsAfter.length; i++) {
          let parsed = parseSpokenNumber(wordsAfter[i]);
          if (parsed !== null) {
            // Check if there is compound
            if (i + 2 < wordsAfter.length && (wordsAfter[i+1].toLowerCase() === 'na' || wordsAfter[i+1].toLowerCase() === 'and')) {
              const parsedComp = parseSpokenNumber(wordsAfter.slice(i, i+3).join(' '));
              if (parsedComp !== null) parsed = parsedComp;
            }
            mark = parsed;
            break;
          }
        }
      }
    }

    if (position !== null) {
      pairs.push({ position, mark });
    }
  }

  // De-duplicate / overwrite logic: If the same position appears twice in one batch,
  // take the second occurrence as the intended value and silently overwrite.
  const uniquePairsMap: { [key: number]: ExtractedPair } = {};
  for (const pair of pairs) {
    uniquePairsMap[pair.position] = pair;
  }

  // Return up to 5 pairs. Ignore any beyond the 5th.
  return Object.values(uniquePairsMap).slice(0, 5);
};
