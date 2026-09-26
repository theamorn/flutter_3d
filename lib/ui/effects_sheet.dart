import 'package:flutter/material.dart';
import '../hotel/feature.dart';
import '../hotel/feature_registry.dart';

class EffectsSheet extends StatelessWidget {
  const EffectsSheet({super.key, required this.registry, this.presetRow});
  final FeatureRegistry registry;

  /// Task 8 passes its preset chips here.
  final Widget? presetRow;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => ListView(controller: scroll, children: [
          ?presetRow,
          for (final tier in CostTier.values) ...[
            ListTile(
                title: Text(tier.name.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge)),
            for (final f in registry.features
                .where((f) => f.tier == tier && f.toggleable))
              SwitchListTile(
                title: Text(f.label),
                value: registry.isEnabled(f.id),
                onChanged: (v) => registry.setEnabled(f.id, v),
              ),
          ],
        ]),
      ),
    );
  }
}
