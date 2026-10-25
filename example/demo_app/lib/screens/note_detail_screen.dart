import 'package:flutter/material.dart';

import '../data/notes_repository.dart';

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final note = const NotesRepository().byId(id);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note not found')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(tooltip: 'Edit', onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: 'Share', onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Chip(label: Text(note.tag)),
          const SizedBox(height: 12),
          Text(note.title, style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            note.updated,
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text(note.body, style: text.bodyLarge),
        ],
      ),
    );
  }
}
