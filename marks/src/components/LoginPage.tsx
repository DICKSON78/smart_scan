import React, { useState } from 'react';
import { LogoIcon, KeyIcon } from './Icons';
import { Spinner } from './Spinner';

interface LoginPageProps {
  onLogin: () => void;
  error: string | null;
  setError: (error: string | null) => void;
}

export const LoginPage: React.FC<LoginPageProps> = ({ onLogin, error, setError }) => {
  const [password, setPassword] = useState('');
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoggingIn(true);
    setError(null);

    // Simulate a small delay for better UX
    setTimeout(() => {
      const storedPassword = localStorage.getItem('smartscan-password') || 'teacher';
      if (password === storedPassword) {
        onLogin();
      } else {
        setError('Incorrect password. Default is "teacher".');
        setIsLoggingIn(false);
      }
    }, 600);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex flex-col justify-center py-12 sm:px-6 lg:px-8 font-sans">
      <div className="sm:mx-auto sm:w-full sm:max-w-md text-center">
        <div className="inline-block bg-blue-900 p-4 rounded-3xl shadow-2xl mb-6">
          <LogoIcon className="w-16 h-16 text-white" />
        </div>
        <h1 className="text-4xl font-extrabold text-gray-900 dark:text-white tracking-tight">SmartScan Marks</h1>
        <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">Secure Access for Educators</p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white dark:bg-gray-800 py-10 px-6 shadow-2xl rounded-3xl sm:px-10 border border-gray-100 dark:border-gray-700">
          <form className="space-y-6" onSubmit={handleSubmit}>
            <div>
              <label htmlFor="password" title="Password" className="block text-sm font-bold text-gray-700 dark:text-gray-300 mb-2">
                Application Password
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <KeyIcon className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="block w-full pl-10 pr-3 py-3 bg-gray-50 dark:bg-gray-900 border border-gray-300 dark:border-gray-600 rounded-xl shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-900 focus:border-transparent sm:text-sm transition-all text-gray-900 dark:text-white"
                  placeholder="Enter password"
                />
              </div>
            </div>

            {error && (
              <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-xl p-4">
                <p className="text-sm text-blue-600 dark:text-blue-400 font-medium text-center">{error}</p>
              </div>
            )}

            <div>
              <button
                type="submit"
                disabled={isLoggingIn}
                className="w-full flex justify-center py-3 px-4 border border-transparent rounded-xl shadow-lg text-lg font-bold text-white bg-blue-900 hover:bg-blue-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-900 transition-all transform active:scale-95 disabled:bg-blue-300 disabled:cursor-not-allowed"
              >
                {isLoggingIn ? <Spinner className="text-white" /> : 'Sign In'}
              </button>
            </div>
          </form>
          
          <div className="mt-8 pt-6 border-t border-gray-100 dark:border-gray-700 text-center">
            <p className="text-xs text-gray-500 dark:text-gray-400">
              By Dickson M Chaula
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
