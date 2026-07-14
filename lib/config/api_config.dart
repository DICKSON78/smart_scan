class ApiConfig {
  /// Gemini API key — pass via: flutter run --dart-define=GEMINI_API_KEY=your_key
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Gemini model to use
  static const String geminiModel = 'gemini-2.5-pro';

  // ── ClickPesa Payment Gateway ──────────────────────────────────────────────
  /// ClickPesa API key — pass via: flutter run --dart-define=CLICKPESA_API_KEY=your_key
  static const String clickPesaApiKey = String.fromEnvironment('CLICKPESA_API_KEY', defaultValue: '');

  /// ClickPesa client ID — pass via: flutter run --dart-define=CLICKPESA_CLIENT_ID=your_id
  static const String clickPesaClientId = String.fromEnvironment('CLICKPESA_CLIENT_ID', defaultValue: '');

  /// How often (seconds) to poll ClickPesa for payment status
  static const int paymentPollIntervalSec = 3;

  /// Max polling attempts (~4.5 min timeout)
  static const int paymentPollMaxAttempts = 90;
}
