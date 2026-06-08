
import React, { useState, useRef, useCallback, useEffect } from 'react';
import { VideoCameraIcon, CameraIcon, TrashIcon, CropIcon } from './Icons';
import { Spinner } from './Spinner';
import { CropModal } from './CropModal';

interface CameraScannerProps {
  onProcess: (base64Images: string[]) => Promise<void>;
  isProcessing: boolean;
}

interface CapturedImage {
    id: string;
    thumbnail: string;
    original: string;
}

export const RealtimeScanner: React.FC<CameraScannerProps> = ({ onProcess, isProcessing }) => {
  const [isCameraOn, setIsCameraOn] = useState(false);
  const [capturedImages, setCapturedImages] = useState<CapturedImage[]>([]);
  const [imageToRecrop, setImageToRecrop] = useState<CapturedImage | null>(null);
  const [error, setError] = useState<string | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [flash, setFlash] = useState(false);
  const [showDebug, setShowDebug] = useState(false);
  const [debugLogs, setDebugLogs] = useState<string[]>([]);

  const addDebugLog = useCallback((msg: string) => {
    setDebugLogs(prev => [...prev.slice(-9), `${new Date().toLocaleTimeString()}: ${msg}`]);
  }, []);

  const stopCamera = useCallback(() => {
    addDebugLog('Stopping camera...');
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
    setIsCameraOn(false);
  }, [addDebugLog]);

  useEffect(() => {
    return () => {
      stopCamera();
    };
  }, [stopCamera]);

  const startCamera = useCallback(async (deviceId?: string) => {
    addDebugLog(`Starting camera (deviceId: ${deviceId || 'default'})...`);
    stopCamera();
    setError(null);
    
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      const msg = 'Browser does not support getUserMedia';
      addDebugLog(msg);
      setError('Your browser does not support camera access. Please try a different browser.');
      setIsCameraOn(false);
      return;
    }

    // Try multiple constraint sets for maximum compatibility
    const constraintSets = deviceId 
      ? [{ video: { deviceId: { exact: deviceId } } }]
      : [
          { video: { facingMode: 'environment' } },
          { video: { facingMode: 'user' } },
          { video: true }
        ];

    let lastErr: Error | null = null;

    for (const constraints of constraintSets) {
      try {
        addDebugLog(`Trying constraints: ${JSON.stringify(constraints)}`);
        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        addDebugLog('getUserMedia SUCCESS');
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          streamRef.current = stream;
          setIsCameraOn(true);
          
          // Ensure video actually starts playing
          const playVideo = () => {
            if (videoRef.current) {
              addDebugLog('Attempting video.play()...');
              videoRef.current.play().then(() => {
                addDebugLog('video.play() SUCCESS');
              }).catch(e => {
                const msg = `video.play() FAILED: ${e.message}`;
                addDebugLog(msg);
                console.error(msg, e);
                // If play fails, it might need a user gesture
                setError("Camera ready. Tap 'Start Camera' again to begin.");
              });
            }
          };

          if (videoRef.current.readyState >= 2) {
            playVideo();
          } else {
            videoRef.current.onloadedmetadata = playVideo;
          }
          
          return;
        }
      } catch (err) {
        const error = err as Error;
        const msg = `Constraint set FAILED (${error.name}): ${error.message}`;
        addDebugLog(msg);
        console.warn(msg, constraints);
        lastErr = error;
        // If it's a permission error, don't keep trying other constraints
        if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
          break;
        }
      }
    }

    addDebugLog(`All attempts FAILED. Last error: ${lastErr?.name}`);
    console.error('All camera attempts failed:', lastErr);
    if (lastErr?.name === 'NotAllowedError' || lastErr?.name === 'PermissionDeniedError' || lastErr?.message?.includes('denied') || lastErr?.message?.includes('not allowed')) {
      setError('Camera access blocked. Click "Open in New Tab" below to enable scanning.');
    } else if (lastErr?.name === 'OverconstrainedError') {
      setError('Could not find a camera matching the requirements.');
    } else {
      setError(`Camera error: ${lastErr?.message || 'Unknown error'}. Please try refreshing the page.`);
    }
    setIsCameraOn(false);
  }, [stopCamera, addDebugLog]);

  useEffect(() => {
    // Auto-start camera when component mounts
    const timer = setTimeout(() => {
      startCamera();
    }, 500);
    return () => {
      clearTimeout(timer);
      stopCamera();
    };
  }, [startCamera, stopCamera]);

  const captureFrame = useCallback(() => {
    if (!videoRef.current) return null;
    const video = videoRef.current;
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx?.drawImage(video, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/jpeg', 0.6);
  }, []);

  const handleTakePicture = useCallback(async () => {
    if (!videoRef.current || isProcessing) return;
    
    const frame = captureFrame();
    if (!frame) return;

    // Visual feedback
    setFlash(true);
    setTimeout(() => setFlash(false), 150);
    
    const id = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2, 15);
    setCapturedImages(prev => [...prev, { id, thumbnail: frame, original: frame }]);
    
    // Auto-process the frame immediately for real-time feel if desired, 
    // but the user said "automatic in batch mode", so we add to batch.
    // However, if we process "in real time", it should probably just add to session.
  }, [captureFrame, isProcessing]);

  // No automatic interval for capture.
  // The user will click the manual capture button instead.

  const handleCropConfirm = (croppedImage: string) => {
    if (!imageToRecrop) return;
    setCapturedImages(prev => prev.map(img => 
        img.id === imageToRecrop.id ? { ...img, thumbnail: croppedImage } : img
    ));
    setImageToRecrop(null);
  };

  const handleCropCancel = () => {
    setImageToRecrop(null);
  };

  const handleDeleteImage = (id: string) => {
    setCapturedImages(prev => prev.filter((img) => img.id !== id));
  };

  const handleProcessImages = async () => {
    if (capturedImages.length === 0) {
      setError("No images captured to process.");
      return;
    }
    setError(null);
    const imagesToProcess = capturedImages.map(img => img.thumbnail);
    await onProcess(imagesToProcess);
    setCapturedImages([]);
  };

  return (
    <>
    {imageToRecrop && (
      <CropModal
        imageSrc={imageToRecrop.original}
        onConfirm={handleCropConfirm}
        onCancel={handleCropCancel}
      />
    )}
    <div className="space-y-4">
      <div className="relative w-full aspect-[3/4] bg-gray-200 dark:bg-gray-900/50 rounded-2xl overflow-hidden border-2 border-gray-300 dark:border-gray-700 shadow-2xl flex items-center justify-center">
        <video 
          ref={videoRef} 
          autoPlay 
          playsInline 
          muted 
          className={`w-full h-full object-cover ${isCameraOn ? 'block' : 'hidden'}`}
        ></video>
        
        {isProcessing && (
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm z-20 flex flex-col items-center justify-center text-white">
            <Spinner size="lg" />
            <p className="mt-4 font-bold animate-pulse">Analyzing Sheet...</p>
          </div>
        )}

        {isCameraOn && !isProcessing && (
          <div className="absolute inset-x-0 bottom-4 pointer-events-none flex flex-col items-center justify-center gap-4">
            <div className="bg-black/40 backdrop-blur-md px-6 py-2 rounded-full border border-white/20 shadow-xl">
              <div className="text-white text-xs font-bold">
                Tap button below to capture
              </div>
            </div>
          </div>
        )}
        
        {flash && (
          <div className="absolute inset-0 bg-white opacity-60 z-10 transition-opacity duration-150"></div>
        )}

        {!isCameraOn && !isProcessing && (
          <div className="text-center p-8 bg-white/50 dark:bg-gray-800/50 backdrop-blur-sm rounded-3xl border-2 border-dashed border-gray-300 dark:border-gray-700 m-4">
            <VideoCameraIcon className="w-20 h-20 mx-auto text-blue-900/40 dark:text-blue-400/40 mb-4 animate-pulse"/>
            <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Initializing...</h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-6 max-w-[200px] mx-auto">Please allow camera access if prompted.</p>
            <div className="flex flex-col gap-3">
              <button 
                onClick={() => startCamera()}
                className="bg-blue-900 text-white px-6 py-3 rounded-xl text-sm font-bold shadow-lg hover:bg-blue-800 active:scale-95 transition-all"
              >
                Retry Camera
              </button>
              <a 
                href={window.location.href} 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-xs text-blue-600 dark:text-blue-400 underline font-bold"
              >
                Open in new tab ↗
              </a>
            </div>
          </div>
        )}
      </div>

      {error && (
        <div className="bg-red-50 dark:bg-red-900/10 border border-red-100 dark:border-red-900/30 p-6 rounded-2xl space-y-4">
          <div className="flex flex-col items-center text-center space-y-2">
            <div className="w-12 h-12 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center mb-2">
               <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-6 h-6 text-red-600 dark:text-red-400">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z" />
                  <path strokeLinecap="round" strokeLinejoin="round" d="m15 13.5-6-6m0 6 6-6" />
               </svg>
            </div>
            <h4 className="font-bold text-gray-900 dark:text-white">Camera Access Required</h4>
            <p className="text-sm text-gray-600 dark:text-gray-400 max-w-[280px]">
              {error}
            </p>
          </div>

          <div className="flex flex-col gap-3">
            <a 
              href={window.location.href} 
              target="_blank" 
              rel="noopener noreferrer"
              className="w-full bg-blue-900 text-white font-bold py-3 px-4 rounded-xl hover:bg-blue-800 flex items-center justify-center gap-2 shadow-lg active:scale-95 transition-all text-sm"
            >
              Open in New Tab ↗
            </a>
            <button 
              onClick={() => startCamera()}
              className="w-full bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 font-bold py-3 px-4 rounded-xl border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all text-sm"
            >
              Retry Permission
            </button>
          </div>

          <button 
            onClick={() => setShowDebug(!showDebug)}
            className="w-full text-center text-[10px] text-gray-400 uppercase tracking-widest hover:text-gray-600 dark:hover:text-gray-200 transition-colors py-2"
          >
            {showDebug ? 'Hide Technical Details' : 'Show Technical Details'}
          </button>
          
          {showDebug && (
            <div className="bg-black text-green-400 p-3 rounded-lg font-mono text-[10px] overflow-auto max-h-40 border border-gray-800">
              <p className="mb-2 border-b border-gray-800 pb-1 text-gray-500 uppercase">Debug Log</p>
              {debugLogs.length === 0 ? <p className="opacity-50 italic">No logs...</p> : (
                <ul className="space-y-1">
                  {debugLogs.map((log, i) => (
                    <li key={i}>{log}</li>
                  ))}
                </ul>
              )}
            </div>
          )}
        </div>
      )}
      
      <div className="flex flex-col space-y-4">
        {isCameraOn && (
          <div className="space-y-4">
            <button 
              onClick={handleTakePicture} 
              disabled={isProcessing} 
              className="w-full bg-blue-900 text-white font-bold py-5 px-4 rounded-2xl hover:bg-blue-800 flex items-center justify-center space-x-4 shadow-xl active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed border-b-4 border-blue-950"
            >
                <div className="relative">
                  <CameraIcon className="w-8 h-8"/>
                </div>
                <div className="flex flex-col items-start">
                  <span className="text-xl leading-tight">Capture & Add to Batch</span>
                  <span className="text-[10px] opacity-70 uppercase tracking-widest font-bold">Manual Scan</span>
                </div>
            </button>

            {capturedImages.length > 0 && (
              <div className="flex gap-2">
                <button
                  onClick={handleProcessImages}
                  disabled={isProcessing}
                  className="flex-grow bg-green-600 text-white font-bold py-3 px-4 rounded-xl hover:bg-green-700 shadow-md flex items-center justify-center space-x-2 transition-all active:scale-95 disabled:bg-green-300"
                >
                  {isProcessing ? <Spinner /> : (
                    <span>Process Batch ({capturedImages.length})</span>
                  )}
                </button>
                <button
                  onClick={() => setCapturedImages([])}
                  disabled={isProcessing}
                  className="px-4 bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 rounded-xl hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors"
                  title="Clear Batch"
                >
                  <TrashIcon className="w-5 h-5" />
                </button>
              </div>
            )}
          </div>
        )}
      </div>
      
      {capturedImages.length > 0 && (
        <div className="space-y-3 pt-4">
            <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200">Captured Sheets ({capturedImages.length})</h3>
            <div className="bg-gray-100 dark:bg-gray-900/50 rounded-lg p-2">
                <ul className="flex gap-3 overflow-x-auto pb-2">
                    {capturedImages.map((img) => (
                        <li key={img.id} className="relative flex-shrink-0 rounded-md overflow-hidden shadow-md group">
                            <img src={img.thumbnail} alt={`Capture ${img.id}`} className="h-24 w-auto object-cover" />
                            <div className="absolute inset-0 bg-black/40 flex items-center justify-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                <button 
                                    onClick={() => setImageToRecrop(img)}
                                    className="bg-white/80 text-gray-800 rounded-full p-2 hover:bg-white transition-colors"
                                    aria-label="Edit crop"
                                >
                                    <CropIcon className="w-5 h-5" />
                                </button>
                                <button 
                                    onClick={() => handleDeleteImage(img.id)} 
                                    className="bg-white/80 text-red-600 rounded-full p-2 hover:bg-white transition-colors"
                                    aria-label="Delete image"
                                >
                                    <TrashIcon className="w-5 h-5" />
                                </button>
                            </div>
                        </li>
                    ))}
                </ul>
            </div>
        </div>
      )}
    </div>
    </>
  );
};
