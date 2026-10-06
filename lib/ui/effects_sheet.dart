import 'package:flutter/material.dart';
import '../hotel/feature.dart';
import '../hotel/feature_registry.dart';
import '../hotel/presets.dart';

class EffectsSheet extends StatelessWidget {
  const EffectsSheet(
      {super.key, required this.registry, this.presetRow, this.previews = const {}});
  final FeatureRegistry registry;

  /// A one-tap preview per feature id (label and action), shown under the
  /// feature's switch while it is on.
  final Map<String, (String, VoidCallback)> previews;

  /// Replaces the default Low / Medium / High / Ultra chips.
  final Widget? presetRow;

  Widget _presetChips() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Wrap(spacing: 8, children: [
          for (final p in Preset.values)
            ActionChip(
              label: Text(p.name[0].toUpperCase() + p.name.substring(1)),
              onPressed: () => applyPreset(registry, p),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => ListView(controller: scroll, children: [
          presetRow ?? _presetChips(),
          for (final tier in CostTier.values) ...[
            ListTile(
                title: Text(tier.name.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge)),
            for (final f in registry.features
                .where((f) => f.tier == tier && f.toggleable))
              ...[
                SwitchListTile(
                  title: Text(f.label),
                  value: registry.isEnabled(f.id),
                  onChanged: (v) => registry.setEnabled(f.id, v),
                ),
                if (previews[f.id] case final preview? when registry.isEnabled(f.id))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: preview.$2, child: Text(preview.$1)),
                  ),
              ],
          ],
        ]),
      ),
    );
  }
}
