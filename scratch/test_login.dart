import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';

import '../lib/core/constants/supabase_constants.dart';
import '../lib/core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  final pin = '1234'; // Or any pin
  final username = 'iwin'; // The username from the screenshot
  
  final bytes = utf8.encode(pin);
  final pinHash = sha256.convert(bytes).toString();
  
  File logFile = File('scratch/login_log.txt');
  await logFile.writeAsString('Starting login test...\n');
  
  try {
    await logFile.writeAsString('Calling rpc...\n', mode: FileMode.append);
    final response = await client.rpc(
      'login_player',
      params: {
        'p_username': username,
        'p_pin_hash': pinHash,
      },
    ).timeout(const Duration(seconds: 10));
    
    await logFile.writeAsString('Response: \$response\n', mode: FileMode.append);
    await logFile.writeAsString('Type: \${response.runtimeType}\n', mode: FileMode.append);
  } catch (e, st) {
    await logFile.writeAsString('Error: \$e\n\$st\n', mode: FileMode.append);
  }
  
  exit(0);
}
