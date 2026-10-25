import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Planted defect: no SafeArea. The page indicator and title sit under the
/// status bar / notch on real devices.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (Icons.landscape_outlined, 'Walk the land', 'Capture what you see, right where you stand.'),
    (Icons.sync_outlined, 'Sync when you can', 'Notes save offline and sync when a signal returns.'),
    (Icons.insights_outlined, 'See the season', 'Tags turn scattered notes into a picture of the year.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Text('Fieldnotes', style: text.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final (icon, title, body) = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(icon, size: 72, color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 40),
                      Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? scheme.primary : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_page < _pages.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      } else {
                        context.go('/login');
                      }
                    },
                    child: Text(_page < _pages.length - 1 ? 'Next' : 'Get started'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
