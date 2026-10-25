import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBar(
              hintText: 'Search notes and tags',
              leading: const Icon(Icons.search),
              onChanged: (_) {},
            ),
            const SizedBox(height: 24),
            Text('Recent', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                ActionChip(label: Text('irrigation')),
                ActionChip(label: Text('Field')),
                ActionChip(label: Text('seed order')),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                'Type to search across all notes.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
