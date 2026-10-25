import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NoteNewScreen extends StatelessWidget {
  const NoteNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New note'),
        leading: IconButton(
          tooltip: 'Discard',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Save')),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            Expanded(
              child: TextField(
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Write what you see…',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
