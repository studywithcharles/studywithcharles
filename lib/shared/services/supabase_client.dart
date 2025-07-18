import 'package:supabase_flutter/supabase_flutter.dart';

/// A singleton wrapper around Supabase.instance.client
class SupabaseClientWrapper {
  SupabaseClientWrapper._();
  static final SupabaseClientWrapper instance = SupabaseClientWrapper._();

  final SupabaseClient client = Supabase.instance.client;
}
