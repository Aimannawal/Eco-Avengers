import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/services/supabase_service.dart';
import '../lib/services/auth_service.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  print('Trying to register a test user...');
  final res = await AuthService.instance.register(
    username: 'testloop_user',
    pin: '1234',
    displayName: 'Test Loop',
  );
  
  print('Register result: \$res');
  
  print('Trying to login...');
  final loginRes = await AuthService.instance.login(
    username: 'testloop_user',
    pin: '1234',
  );
  print('Login result: \$loginRes');
  
  exit(0);
}
