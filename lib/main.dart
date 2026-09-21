import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  // Bắt buộc trước mọi lệnh gọi plugin: Supabase đọc Keychain/Keystore ngay
  // trong initialize, mà kênh nền tảng chưa sẵn sàng thì lệnh đó ném lỗi.
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const NextPleaseApp());
}
