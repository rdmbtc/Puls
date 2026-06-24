import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/puls_app.dart';
import 'core/secrets.dart';
import 'core/utils/kv_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture an inbound referral code (?ref=CODE) BEFORE Google OAuth redirects
  // away — we persist it to localStorage so it survives the round-trip and can
  // be auto-claimed once the invitee signs in. See WalletService._maybeClaimReferral.
  _captureReferralCode();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const PulsApp());
}

void _captureReferralCode() {
  try {
    final raw = Uri.base.queryParameters['ref'];
    if (raw == null) return;
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.isNotEmpty && code.length <= 12) {
      kvSet('puls_ref', code);
    }
  } catch (_) {
    // Never block app startup over a malformed URL.
  }
}
