import React, { useState } from 'react';
import { BackIcon, SunIcon, MoonIcon, DesktopIcon, KeyIcon, LogoutIcon, TrashIcon, CloudIcon, LogoIcon } from './Icons';
import { OcrEngine } from '../App';


interface SettingsPageProps {
  onClose: () => void;
  theme: string;
  setTheme: (theme: string) => void;
  ocrEngine: OcrEngine;
  setOcrEngine: (engine: OcrEngine) => void;
  onLogout: () => void;
  onClearAllData: () => void;
}

export const SettingsPage: React.FC<SettingsPageProps> = ({ onClose, theme, setTheme, ocrEngine, setOcrEngine, onLogout, onClearAllData }) => {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordMessage, setPasswordMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const handlePasswordChange = (e: React.FormEvent) => {
    e.preventDefault();
    const storedPassword = localStorage.getItem('smartscan-password') || 'teacher';
    
    if (currentPassword !== storedPassword) {
      setPasswordMessage({ type: 'error', text: 'Current password is incorrect.' });
      return;
    }
    if (!newPassword || newPassword.length < 4) {
      setPasswordMessage({ type: 'error', text: 'New password must be at least 4 characters long.' });
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordMessage({ type: 'error', text: 'New passwords do not match.' });
      return;
    }
    
    localStorage.setItem('smartscan-password', newPassword);
    setPasswordMessage({ type: 'success', text: 'Password updated successfully!' });
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setTimeout(() => setPasswordMessage(null), 3000);
  };

  const themeOptions = [
    { name: 'light', label: 'Light', icon: SunIcon },
    { name: 'dark', label: 'Dark', icon: MoonIcon },
    { name: 'system', label: 'System', icon: DesktopIcon },
  ];
  
  const ocrOptions: {name: OcrEngine, label: string, description: string, icon: React.FC<{className?:string}>}[] = [
    { name: 'gemini', label: 'Gemini AI', description: 'Cloud-based, highest accuracy.', icon: CloudIcon },
    { name: 'claude', label: 'Claude AI', description: 'Powerful OCR via Anthropic API.', icon: KeyIcon },
    { name: 'paddle', label: 'PaddleOCR', description: 'Local, high-speed & offline.', icon: LogoIcon },
  ];

  return (
    <div className="min-h-screen bg-gray-100 dark:bg-gray-900 px-4 py-8 text-gray-800 dark:text-gray-200">
      <div className="max-w-3xl mx-auto">
        <header className="mb-8">
          <button onClick={onClose} className="flex items-center space-x-2 text-blue-900 dark:text-blue-400 hover:underline font-semibold">
            <BackIcon className="w-5 h-5" />
            <span>Back to App</span>
          </button>
        </header>
        
        <main className="space-y-12">
          <h1 className="text-4xl font-extrabold text-gray-900 dark:text-white text-center">Settings</h1>
          
          {/* Theme Settings */}
          <section className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg">
            <h2 className="text-xl font-bold mb-4 flex items-center gap-2"><DesktopIcon className="w-6 h-6 text-blue-900" />Appearance</h2>
            <div className="grid grid-cols-3 gap-4">
              {themeOptions.map(opt => (
                <button
                  key={opt.name}
                  onClick={() => setTheme(opt.name)}
                  className={`flex flex-col items-center justify-center p-4 rounded-lg border-2 transition-all duration-200 ${
                    theme === opt.name
                      ? 'border-blue-900 bg-blue-50 dark:bg-blue-900/30 ring-2 ring-blue-900'
                      : 'border-gray-300 dark:border-gray-600 hover:border-blue-800 dark:hover:border-blue-500'
                  }`}
                >
                  <opt.icon className="w-8 h-8 mb-2" />
                  <span className="font-semibold">{opt.label}</span>
                </button>
              ))}
            </div>
          </section>
          
          {/* OCR Engine Settings */}
          <section className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg">
            <h2 className="text-xl font-bold mb-2 flex items-center gap-2"><CloudIcon className="w-6 h-6 text-blue-900" />OCR Engine</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Choose the engine for text recognition. <strong>Gemini AI</strong> is cloud-based and highly accurate (recommended fallback). 
              <strong>PaddleOCR</strong> runs locally on your device for extreme speed and offline support.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {ocrOptions.map(opt => (
                <button
                  key={opt.name}
                  onClick={() => setOcrEngine(opt.name)}
                  className={`flex items-center text-left p-4 rounded-lg border-2 transition-all duration-200 ${
                    ocrEngine === opt.name
                      ? 'border-blue-900 bg-blue-50 dark:bg-blue-900/30 ring-2 ring-blue-900'
                      : 'border-gray-300 dark:border-gray-600 hover:border-blue-800 dark:hover:border-blue-500'
                  }`}
                >
                  <opt.icon className="w-10 h-10 mr-4 flex-shrink-0" />
                  <div>
                    <span className="font-semibold block">{opt.label}</span>
                    <span className="text-sm text-gray-600 dark:text-gray-400">{opt.description}</span>
                  </div>
                </button>
              ))}
            </div>
          </section>

          {/* Password Settings */}
          <section className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg">
            <h2 className="text-xl font-bold mb-4 flex items-center gap-2"><KeyIcon className="w-6 h-6 text-blue-900" />Change Password</h2>
            <form onSubmit={handlePasswordChange} className="space-y-4">
              <input
                type="password"
                placeholder="Current Password"
                value={currentPassword}
                onChange={e => setCurrentPassword(e.target.value)}
                required
                className="w-full px-3 py-2 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-900 focus:border-blue-900"
              />
              <input
                type="password"
                placeholder="New Password"
                value={newPassword}
                onChange={e => setNewPassword(e.target.value)}
                required
                className="w-full px-3 py-2 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-900 focus:border-blue-900"
              />
              <input
                type="password"
                placeholder="Confirm New Password"
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                required
                className="w-full px-3 py-2 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-900 focus:border-blue-900"
              />
              {passwordMessage && (
                <p className={`text-sm text-center ${passwordMessage.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>
                  {passwordMessage.text}
                </p>
              )}
              <button type="submit" className="w-full bg-blue-900 text-white font-bold py-2 px-4 rounded-lg hover:bg-blue-800 transition-colors">
                Update Password
              </button>
            </form>
          </section>

          {/* Session & Data Management */}
           <section className="p-6 bg-white dark:bg-gray-800 rounded-2xl shadow-lg space-y-4">
               <h2 className="text-xl font-bold mb-2 flex items-center gap-2">Session & Data</h2>
                <button
                    onClick={onLogout}
                    className="w-full flex items-center justify-center gap-2 bg-blue-500 text-white font-bold py-2 px-4 rounded-lg hover:bg-blue-600 transition-colors"
                >
                    <LogoutIcon className="w-5 h-5" />
                    <span>Logout</span>
                </button>
                <button
                    onClick={onClearAllData}
                    className="w-full flex items-center justify-center gap-2 bg-red-600 text-white font-bold py-2 px-4 rounded-lg hover:bg-red-700 transition-colors"
                >
                    <TrashIcon className="w-5 h-5" />
                    <span>Clear All Application Data</span>
                </button>
           </section>
        </main>
      </div>
    </div>
  );
};