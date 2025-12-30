import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// 🔥 Background notification import
import 'package:just_audio_background/just_audio_background.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'splash_screen.dart';
import 'home_screen.dart';
import 'now_playing_screen.dart';
import 'theme.dart';

// 🌎 EasyLocalization wrap ke saath
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✅ AdMob init (must)
  await MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: const []),
  );

  // 🔥 Notification Background Init (beta.17 compatible)
  await JustAudioBackground.init(
    androidNotificationChannelId: 'youplay_music_channel',
    androidNotificationChannelName: 'YouPlay Music',
    androidNotificationOngoing: true,
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('es'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: const YouplayMusicApp(),
    ),
  );
}

class YouplayMusicApp extends StatelessWidget {
  const YouplayMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: currentTheme,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Music Player',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(theme),

          // 🌎 Localization
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

          initialRoute: SplashScreen.routeName,
          routes: {
            SplashScreen.routeName: (_) => const SplashScreen(),
            HomeScreen.routeName: (_) => const HomeScreen(),
            NowPlayingScreen.routeName: (_) => const NowPlayingScreen(),
          },
        );
      },
    );
  }
}
