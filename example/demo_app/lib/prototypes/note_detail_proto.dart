// Prototype directions for a redesigned note detail screen. Throwaway code:
// only compiled into the router when built with --dart-define=UI_PROTO=true.
// Used by the cerebro-design skill's prototype mode and by the demo capture
// (`dart run cerebro capture -D UI_PROTO=true`).
import 'package:flutter/material.dart';

const _title = 'Soil sample, north field';
const _body =
    'pH 6.4, slightly compacted at 20 cm. Earthworm count good. Re-test after the rain. '
    'Next step: compare with the south field sample before ordering lime.';

/// Direction A: text-first, metadata as a quiet row under the title.
class NoteDetailProtoA extends StatelessWidget {
  const NoteDetailProtoA({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: 'Edit', onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
        IconButton(tooltip: 'Share', onPressed: () {}, icon: const Icon(Icons.share_outlined)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(_title, style: text.headlineSmall),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.sell_outlined, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('Field', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 16),
            Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('Today, 09:12', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 24),
          Text(_body, style: text.bodyLarge),
        ],
      ),
    );
  }
}

/// Direction B: hero tile with the tag colour, metadata card, body below.
class NoteDetailProtoB extends StatelessWidget {
  const NoteDetailProtoB({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.medium(
          title: const Text(_title),
          actions: [
            IconButton(tooltip: 'Share', onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(children: [
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Field', style: text.titleSmall),
                      Text('Today, 09:12',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Text(_body, style: text.bodyLarge),
          ]),
        ),
      ]),
    );
  }
}
