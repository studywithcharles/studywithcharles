// lib/config.dart
import 'package:flutter/foundation.dart' show kIsWeb;

/// Read Supabase config from dart-define at compile time for web builds.
/// Example build command:
/// flutter build web --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=public-anon-key
class Config {
  // These are compile-time constants captured by String.fromEnvironment
  static const String _supabaseUrlEnv = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKeyEnv = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Use these on web builds. They will be empty if NOT provided via --dart-define.
  static String get supabaseUrlFromDartDefine => _supabaseUrlEnv;
  static String get supabaseAnonKeyFromDartDefine => _supabaseAnonKeyEnv;

  /// Convenience helper for code that needs to know whether we have web defines.
  static bool get hasWebSupabaseDefines =>
      kIsWeb && _supabaseUrlEnv.isNotEmpty && _supabaseAnonKeyEnv.isNotEmpty;
}
