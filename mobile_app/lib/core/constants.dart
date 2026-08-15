import 'package:flutter_dotenv/flutter_dotenv.dart';

String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

// The URL to our Node.js Backend for secure transactions and OTP
String get backendApiUrl => dotenv.env['BACKEND_API_URL'] ?? 'http://localhost:3001';
