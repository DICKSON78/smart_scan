import 'dart:async';
import 'dart:io';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  static ConnectivityService get instance => _instance;
  ConnectivityService._();

  bool _isOnline = true;
  Timer? _timer;

  bool get isOnline => _isOnline;

  void start() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _isOnline = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
