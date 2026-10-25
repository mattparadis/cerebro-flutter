import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A screen where the system back button is intentionally disabled: the
/// user must choose a plan or tap "Not now".
///
/// Planted defect: hardcoded background colour instead of a ColorScheme
/// role, so dark mode does not adapt.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFE0F2F1),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text('Fieldnotes Pro', style: text.headlineMedium?.copyWith(color: const Color(0xFF004D40))),
                const SizedBox(height: 8),
                Text(
                  'Unlimited photos, PDF export, and shared notebooks.',
                  style: text.bodyLarge?.copyWith(color: const Color(0xFF00695C)),
                ),
                const SizedBox(height: 32),
                const _Plan(title: 'Yearly', price: '€29.99 / year', badge: 'Save 40%', selected: true),
                const SizedBox(height: 12),
                const _Plan(title: 'Monthly', price: '€3.99 / month'),
                const Spacer(),
                FilledButton(onPressed: () {}, child: const Text('Start 7-day free trial')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/notes'),
                  child: const Text('Not now'),
                ),
                Text(
                  'Cancel anytime. Billed after the trial ends.',
                  style: text.bodySmall?.copyWith(color: const Color(0xFF00695C)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.title, required this.price, this.badge, this.selected = false});

  final String title;
  final String price;
  final String? badge;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const accent = Color(0xFF00695C);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? accent : const Color(0xFFB2DFDB), width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(color: const Color(0xFF004D40))),
                Text(price, style: text.bodyMedium?.copyWith(color: const Color(0xFF00695C))),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
              child: Text(badge!, style: text.labelSmall?.copyWith(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
