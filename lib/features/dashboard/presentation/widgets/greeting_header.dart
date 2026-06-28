// greeting_header.dart
import 'package:flutter/material.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_greeting(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        const Text('Your Finances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
