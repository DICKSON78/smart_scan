import 'package:flutter_test/flutter_test.dart';
import 'package:exam_mark_extractor/providers/auth_provider.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    final auth = AuthProvider();
    await auth.tryAutoLogin();
    expect(auth.isAuthenticated, false);
  });
}
