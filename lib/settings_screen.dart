// lib/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:headset_connection_event/headset_event.dart';
import 'package:url_launcher/url_launcher.dart';
import 'playing_manager.dart'; // ✅ to pause player when unplugged
import 'setup_device_screen.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool pauseOnDetach = true;
  bool allowBackground = true;

  String _currentLanguageName(BuildContext context) {
    final code = context.locale.languageCode;
    switch (code) {
      case 'hi':
        return 'language_current_hi'.tr();
      case 'es':
        return 'language_current_es'.tr();
      case 'en':
      default:
        return 'language_current_en'.tr();
    }
  }

  final HeadsetEvent _headsetEvent = HeadsetEvent();

  @override
  void initState() {
    super.initState();
    _listenHeadsetEvents();
  }

  void _listenHeadsetEvents() async {
    // get current state once (optional)
    await _headsetEvent.getCurrentState;

    // continuous listener
    _headsetEvent.setListener((HeadsetState state) {
      if (pauseOnDetach && state == HeadsetState.DISCONNECT) {
        final player = PlayerManager.I.player;
        if (player.playing) {
          player.pause();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎧 Headphones disconnected — playback paused'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    try {
      // safely clear listener — this plugin doesn’t support null argument
      _headsetEvent.setListener((_) {});
    } catch (_) {
      // ignore any errors safely
    }
    super.dispose();
  }

  Widget _tile(
      IconData icon,
      String title, [
        String? subtitle,
        VoidCallback? onTap,
        Widget? trailing,
      ]) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
        subtitle,
        style: const TextStyle(color: Colors.white60),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text('settings_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('general'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ),
          _tile(
            Icons.emoji_objects_outlined,
            'skin_themes'.tr(),
            'skin_themes_sub'.tr(),
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemePickerScreen()),
              );
            },
          ),

          _tile(
            Icons.swap_horiz,
            'setup_device'.tr(),
            'setup_device_sub'.tr(),
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SetupDeviceScreen(),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: Icon(Icons.play_circle_fill,
                color: Theme.of(context).colorScheme.primary),
            title: Text('allow_bg'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                'allow_bg_sub'.tr(),
                style: const TextStyle(color: Colors.white60)),
            value: allowBackground,
            onChanged: (v) => setState(() => allowBackground = v),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          SwitchListTile(
            secondary: Icon(Icons.pause_circle_filled,
                color: Theme.of(context).colorScheme.primary),
            title: Text('pause_on_detach'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                'pause_on_detach_sub'.tr(),
                style: const TextStyle(color: Colors.white60)),
            value: pauseOnDetach,
            onChanged: (v) => setState(() => pauseOnDetach = v),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          ListTile(
            leading: Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
            title: Text('language'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentLanguageName(context),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 8),
                 Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageScreen(),
                ),
              );
            },
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16),
          ),

          // ---------------- HELP SECTION ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'settings_help'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          _tile(
            Icons.help_outline,
            'settings_faq_title'.tr(),
            'settings_faq_sub'.tr(),
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              );
            },
          ),
          _tile(
            Icons.rate_review,
            'settings_rate_title'.tr(),
            'settings_rate_sub'.tr(),
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RateUsScreen()),
              );
            },
          ),
          _tile(
            Icons.privacy_tip_outlined,
            'settings_privacy_title'.tr(),
            'settings_privacy_sub'.tr(),
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          _tile(
            Icons.terminal_outlined,
            'settings_terms_title'.tr(),
            'settings_terms_sub'.tr(),
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

//
// --------------- FAQ SCREEN ---------------
//

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  Widget _q(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
  );

  Widget _a(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      height: 1.4,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Here are answers to some of the most common questions about this music player.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),

            _q('Which audio files does the app support?'),
            _a(
              'The player works with the most common formats available on your device, '
                  'such as MP3, AAC, WAV and others that are supported by your phone. '
                  'All songs are read directly from your device storage — no upload is required.',
            ),

            _q('Where do my songs come from?'),
            _a(
              'The app scans your device storage using the system media library and shows '
                  'all compatible audio files. We do not download any songs from the internet '
                  'and we do not host or distribute music.',
            ),

            _q('Can I use the app offline?'),
            _a(
              'Yes. The app is designed to work completely offline with the music that is '
                  'already saved on your device. An internet connection is only needed for features '
                  'like online help or app updates.',
            ),

            _q('What is the mini player and how do I use it?'),
            _a(
              'The mini player appears at the bottom of the screen when a song is playing. '
                  'You can tap it to open the full Now Playing screen, swipe left or right to change tracks, '
                  'or close it using the cut (×) button.',
            ),

            _q('How do playlists work?'),
            _a(
              'You can create and manage playlists from the Playlist tab. Once a playlist is created, '
                  'add songs to it from your library. Playlists are stored on your device and are available '
                  'whenever you open the app.',
            ),

            _q('Why does the app need storage / audio permission?'),
            _a(
              'Storage or audio library permission is required so the app can read the songs that '
                  'are stored on your device. We only use this permission to show and play your local music.',
            ),

            _q('My songs are not showing in the app. What can I do?'),
            _a(
              'First, make sure the files are actually on your device storage and playable in other apps. '
                  'Then open Settings → Apps → this music player → Permissions and confirm that storage / audio '
                  'permission is granted. You can also try refreshing or restarting the app.',
            ),

            _q('How do I contact support?'),
            _a(
              'If you need help or want to report a problem, please use the Feedback option in the '
                  'Settings screen. Include as many details as possible so we can assist you quickly.',
            ),
          ],
        ),
      ),
    );
  }
}

//
// --------------- RATE US SCREEN ---------------
//

class RateUsScreen extends StatelessWidget {
  const RateUsScreen({super.key});

  Future<void> _onRateTap(BuildContext context) async {
    const String playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.youplay.app.youplay_music';

    final Uri url = Uri.parse(playStoreUrl);

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Play Store'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate us'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you enjoy using this music player, please take a moment '
                  'to rate us on the store. Your support helps us keep improving '
                  'the app and adding new features.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _onRateTap(context),
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text('Rate on store'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thank you for being a part of our music community! 💜',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

//
// --------------- PRIVACY POLICY SCREEN ---------------
//

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Widget _h(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );

  Widget _p(String text) => Text(
    text,
    style: const TextStyle(color: Colors.white70, height: 1.4),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _p(
              'This Privacy Policy explains how this music player app '
                  'handles your information. The app is designed primarily '
                  'for offline playback of audio files stored on your device.',
            ),

            _h('1. Information we access'),
            _p(
              '• Audio and media files: We read metadata about songs stored on '
                  'your device (such as title, artist, album and duration) so that we can '
                  'display and play your music library inside the app.\n'
                  '• Storage and media library: We request storage / audio permissions only '
                  'to locate and manage your local music files.',
            ),

            _h('2. Information we do NOT collect'),
            _p(
              'We do not require you to create an account and we do not '
                  'collect personal identifiers such as your name, address, or password. '
                  'Your music library and playlists remain on your device and are not uploaded '
                  'to our servers.',
            ),

            _h('3. Analytics and crash data'),
            _p(
              'If analytics or crash reporting is enabled in a future version, it will be '
                  'used only to understand app performance and fix issues. Such data would be '
                  'processed in an aggregated way and would not be used to identify you personally.',
            ),

            _h('4. Third-party services'),
            _p(
              'The app may use trusted third-party libraries to play audio or query media '
                  'information. These libraries operate within the app and do not receive your '
                  'personal details from us.',
            ),

            _h('5. Permissions'),
            _p(
              'The app may ask for the following permissions:\n'
                  '• Storage / Media library: to read and play audio files stored on your device.\n'
                  '• Headset / audio focus: to respond when headphones are connected or disconnected.\n'
                  'Permissions can be managed at any time from your device settings.',
            ),

            _h('6. Data security'),
            _p(
              'We aim to keep your data safe by limiting what we access and by processing your '
                  'music library locally on your device. You are responsible for keeping your device '
                  'secure and updated.',
            ),

            _h('7. Changes to this policy'),
            _p(
              'We may update this Privacy Policy from time to time to reflect new features or '
                  'legal requirements. When we make material changes, we will update the version '
                  'shown in the app settings.',
            ),

            _h('8. Contact'),
            _p(
              'If you have questions about this Privacy Policy or how your information is handled, '
                  'please contact us via the Feedback section in the app.',
            ),

            const SizedBox(height: 12),
            const Text(
              'This text is a general description and does not replace professional legal advice. '
                  'Please adapt it to your actual data practices if you publish the app.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

//
// --------------- TERMS OF USE SCREEN ---------------
//

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  Widget _h(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );

  Widget _p(String text) => Text(
    text,
    style: const TextStyle(color: Colors.white70, height: 1.4),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _p(
              'By installing and using this music player app, you agree to the following terms. '
                  'Please read them carefully before using the app.',
            ),

            _h('1. Personal, non-commercial use'),
            _p(
              'This app is provided for your personal, non-commercial use. You may use it to play '
                  'audio files that you legally own or have the right to use. You are responsible for '
                  'ensuring that your use of the app complies with all applicable laws and copyright rules.',
            ),

            _h('2. No music provided'),
            _p(
              'The app does not provide, sell or distribute any music. It only plays audio files that '
                  'are already stored on your device or accessible through your system media library.',
            ),

            _h('3. User responsibility'),
            _p(
              'You are fully responsible for the content you access through the app and for any '
                  'consequences of using or sharing that content. We are not responsible for any loss '
                  'of data, device damage or issues caused by third-party files.',
            ),

            _h('4. Modifications and updates'),
            _p(
              'We may add, remove or modify features of the app at any time to improve performance '
                  'or user experience. Some changes may be delivered as updates through the app store.',
            ),

            _h('5. Limitations of liability'),
            _p(
              'The app is provided on an “as is” basis, without any express or implied warranties. '
                  'To the maximum extent permitted by law, we are not liable for any direct or indirect '
                  'damages arising from the use or inability to use the app.',
            ),

            _h('6. Third-party content and services'),
            _p(
              'The app may interact with third-party libraries, system services or other apps on your '
                  'device. We do not control these third parties and are not responsible for their content, '
                  'privacy practices or terms.',
            ),

            _h('7. Termination of use'),
            _p(
              'You may stop using the app at any time by uninstalling it from your device. We may also '
                  'limit or terminate access to the app if you misuse it or violate these Terms.',
            ),

            _h('8. Changes to these Terms'),
            _p(
              'We may update these Terms of Use periodically. Continued use of the app after changes are '
                  'published means that you accept the updated terms.',
            ),

            _h('9. Contact'),
            _p(
              'If you have questions about these Terms of Use, please contact us through the Feedback '
                  'section in the app.',
            ),

            const SizedBox(height: 12),
            const Text(
              'This text is a general template and does not replace professional legal advice. '
                  'Please review and customise it according to your needs before publishing the app.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- SKIN THEME PICKER SCREEN ----------------

class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = <_ThemeOption>[
      _ThemeOption(
        theme: AppTheme.darkPink,
        name: 'Neon Dark',
        description: 'Purple neon on deep dark background',
        color: const Color(0xFF7E57FF),
      ),

      _ThemeOption(
        theme: AppTheme.amoledPink,
        name: 'AMOLED Black',
        description: 'Pure black with pink highlights',
        color: Theme.of(context).colorScheme.primary
      ),
      _ThemeOption(
        theme: AppTheme.deepPurple,
        name: 'Deep Purple',
        description: 'Purple glow, studio vibe',
        color: const Color(0xFFBB86FC),
      ),
      _ThemeOption(
        theme: AppTheme.warmOrange,
        name: 'Warm Sunset',
        description: 'Warm orange on deep dark background',
        color: const Color(0xFFFFB74D),
      ),
      _ThemeOption(
        theme: AppTheme.cyanMusic,
        name: 'Cyan Music',
        description: 'Neon cyan on deep blue background',
        color: const Color(0xFF2FE6E6),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin themes'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: options.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, index) {
          final opt = options[index];
          final isSelected = currentTheme.value == opt.theme;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: opt.color,
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
            title: Text(
              opt.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              opt.description,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: isSelected
                ? const Icon(Icons.radio_button_checked,
                color: Colors.pinkAccent)
                : const Icon(Icons.radio_button_unchecked,
                color: Colors.white38),
            onTap: () {
              currentTheme.value = opt.theme; // 🔥 yahi se design change
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

class _ThemeOption {
  final AppTheme theme;
  final String name;
  final String description;
  final Color color;

  _ThemeOption({
    required this.theme,
    required this.name,
    required this.description,
    required this.color,
  });
}

// --------------- LANGUAGE SCREEN ---------------

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;

    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'hi', 'name': 'हिन्दी'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('language'.tr()),
      ),
      body: ListView.builder(
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final lang = languages[index];
          final code = lang['code']!;
          final name = lang['name']!;
          final selected = code == currentCode;

          return ListTile(
            title: Text(name),
            trailing: selected
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () async {
              await context.setLocale(Locale(code));
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          );
        },
      ),
    );
  }
}
