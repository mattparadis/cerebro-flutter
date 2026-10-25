import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.eco_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          Text('Fieldnotes', style: text.headlineSmall, textAlign: TextAlign.center),
          Text(
            'Version 0.1.0 (demo)',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const ListTile(title: Text('Privacy policy'), trailing: Icon(Icons.open_in_new)),
          const ListTile(title: Text('Terms of use'), trailing: Icon(Icons.open_in_new)),
          const ListTile(title: Text('Open source licences'), trailing: Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}
