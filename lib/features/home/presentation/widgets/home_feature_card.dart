import 'package:flutter/material.dart';

/// A navigable feature entry in the POS home dashboard.
class FeatureItem {
  const FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

/// A card widget that displays a feature item on the home page.
class HomeFeatureCard extends StatelessWidget {
  const HomeFeatureCard({
    super.key,
    required this.feature,
    this.onTap,
  });

  final FeatureItem feature;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(feature.icon, size: 32),
        title: Text(feature.title),
        subtitle: Text(feature.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
