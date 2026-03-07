import 'package:provider/provider.dart';
import 'providers/translation_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TranslationProvider()),
      ],
      child: const GovTranslatorApp(),
    ),
  );
}

class GovTranslatorApp extends StatelessWidget {
  const GovTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gov Translate AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
