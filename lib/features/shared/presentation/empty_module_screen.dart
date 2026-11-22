import 'package:flutter/material.dart';

import '../../../core/widgets/page_header.dart';

class EmptyModuleScreen extends StatelessWidget {
  const EmptyModuleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 28),
          Expanded(
            child: Card(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 56, color: Colors.blueGrey.shade300),
                      const SizedBox(height: 18),
                      Text(
                        'Ready for the next milestone',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
