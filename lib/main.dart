import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/i18n.dart';
import 'core/push.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await LanguageChoice.load();
  applyLanguage(LanguageChoice.initial ?? systemLanguage());

  // Without config the app still starts and the login screen explains what is missing.
  await Supabase.initialize(
    url: Config.isConfigured ? Config.supabaseUrl : 'https://not-configured.supabase.co',
    publishableKey: Config.isConfigured ? Config.supabaseKey : 'not-configured',
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  await PushService.instance.init();

  runApp(const ProviderScope(child: SeeUApp()));
}
