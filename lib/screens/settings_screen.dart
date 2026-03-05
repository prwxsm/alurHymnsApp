import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _launchPhoneDialer() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+256775671562');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setting')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('About APP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Developers', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('This app was designed and developed by IndeliCraft'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Info', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Version 1.0.0'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_medium_outlined),
            title: const Text('Theme Color'),
            value: settings.isDarkMode,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleTheme();
            },
          ),
          ListTile(
            leading: const Icon(Icons.text_format),
            title: const Text('Font Style'),
            trailing: DropdownButton<double>(
              value: [14.0, 18.0, 22.0, 26.0].contains(settings.fontSize) ? settings.fontSize : 18.0,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 14.0, child: Text('Small')),
                DropdownMenuItem(value: 18.0, child: Text('Medium')),
                DropdownMenuItem(value: 22.0, child: Text('Large')),
                DropdownMenuItem(value: 26.0, child: Text('Extra Large')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).setFontSize(val);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.phone_in_talk_outlined),
            title: const Text('Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Get in touch with us'),
            onTap: _launchPhoneDialer,
          ),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('Rate', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Share your thoughts & experiences\nwith us by rating or review on Google Play Store'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
