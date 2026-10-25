import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          ListTile(
            leading: const CircleAvatar(child: Text('M')),
            title: const Text('Matt'),
            subtitle: const Text('matt@example.com'),
            // Planted defect: 32x32 tap target, below the 48dp minimum.
            trailing: SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: 'Edit profile',
                onPressed: () {},
                icon: const Icon(Icons.edit),
              ),
            ),
          ),
          const _SectionHeader('Sync'),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Sync on Wi-Fi only'),
          ),
          SwitchListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Back up photos'),
            subtitle: const Text('Uses more storage'),
          ),
          const _SectionHeader('Appearance'),
          const ListTile(
            title: Text('Theme'),
            subtitle: Text('System'),
            trailing: Icon(Icons.chevron_right),
          ),
          const _SectionHeader('More'),
          ListTile(
            title: const Text('Fieldnotes Pro'),
            subtitle: const Text('Unlimited photos and export'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/paywall'),
          ),
          ListTile(
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/about'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
