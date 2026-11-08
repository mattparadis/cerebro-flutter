import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/notes_repository.dart';

/// Creation flow with a real contract: Save persists through the
/// repository and pops with the new note; Save is disabled while empty
/// or in flight (no double submit); a failed save shows an inline error
/// and keeps the text; Discard on a dirty form asks first.
class NoteNewScreen extends StatefulWidget {
  const NoteNewScreen({super.key});

  @override
  State<NoteNewScreen> createState() => _NoteNewScreenState();
}

class _NoteNewScreenState extends State<NoteNewScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  String? _error;

  bool get _dirty => _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;
  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = await const NotesRepository().add(title: _title.text, body: _body.text);
      if (!mounted) return;
      setState(() => _saved = true); // let PopScope allow the pop
      context.pop(note);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save the note. Check your connection and try again.";
      });
    }
  }

  Future<void> _discard() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    final discard = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Discard this note?'),
        content: const Text('Your text will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty || _saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New note'),
          leading: IconButton(
            tooltip: 'Discard',
            icon: const Icon(Icons.close),
            onPressed: _saving ? null : _discard,
          ),
          actions: [
            TextButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, color: scheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error))),
                      TextButton(onPressed: _save, child: const Text('Retry')),
                    ],
                  ),
                ),
              TextField(
                controller: _title,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
                style: text.titleLarge,
              ),
              Expanded(
                child: TextField(
                  controller: _body,
                  enabled: !_saving,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(hintText: 'Write what you see…', border: InputBorder.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
