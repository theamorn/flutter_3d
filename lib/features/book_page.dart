import 'package:flutter/material.dart';
import '../data/pokemon.dart';

/// The layout size of a single book page in logical pixels.
const Size kBookPageSize = Size(512, 700);

/// Background color resembling cream paper / parchment.
const Color kBookPaperColor = Color(0xFFFFFDF5);

/// Single Pokédex page rendered onto a 3D book surface via [WidgetComponent].
class BookPage extends StatelessWidget {
  const BookPage({
    super.key,
    required this.result,
    this.onRetry,
  });

  final PokemonResult? result;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kBookPageSize.width,
      height: kBookPageSize.height,
      child: Material(
        color: kBookPaperColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8DFCE), width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final res = result;
    if (res == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF8B5A2B)),
            SizedBox(height: 16),
            Text(
              'Loading…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A4634),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (res is PokemonLoadFailure) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.refresh_rounded, size: 56, color: Color(0xFFC0392B)),
              SizedBox(height: 16),
              Text(
                'Couldn\'t load — tap to retry',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC0392B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (res is PokemonLoaded) {
      final p = res.pokemon;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: #025 Pikachu and type chips
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${p.id.toString().padLeft(3, '0')} ${p.displayName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final type in p.types)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _typeColor(type),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Official artwork
          Expanded(
            child: Center(
              child: p.artworkUrl.isNotEmpty
                  ? Image.network(
                      p.artworkUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        Icons.catching_pokemon,
                        size: 90,
                        color: Color(0xFFE74C3C),
                      ),
                    )
                  : const Icon(
                      Icons.catching_pokemon,
                      size: 90,
                      color: Color(0xFFE74C3C),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Height and Weight
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBE1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: Text(
                    'Height: ${(p.heightDm / 10).toStringAsFixed(1)} m',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A3B32),
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    'Weight: ${(p.weightHg / 10).toStringAsFixed(1)} kg',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A3B32),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 6 Stat bars
          _buildStatBar('HP', p.stats['hp'] ?? 0, const Color(0xFF2ECC71)),
          _buildStatBar('Attack', p.stats['attack'] ?? 0, const Color(0xFFE67E22)),
          _buildStatBar('Defense', p.stats['defense'] ?? 0, const Color(0xFFF39C12)),
          _buildStatBar('Sp. Atk', p.stats['special-attack'] ?? 0, const Color(0xFF3498DB)),
          _buildStatBar('Sp. Def', p.stats['special-defense'] ?? 0, const Color(0xFF9B59B6)),
          _buildStatBar('Speed', p.stats['speed'] ?? 0, const Color(0xFF1ABC9C)),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatBar(String label, int value, Color color) {
    final double fraction = (value / 255.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5A4634),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5DDD0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'grass':
        return const Color(0xFF78C850);
      case 'fire':
        return const Color(0xFFF08030);
      case 'water':
        return const Color(0xFF6890F0);
      case 'electric':
        return const Color(0xFFF8D030);
      case 'poison':
        return const Color(0xFFA040A0);
      case 'bug':
        return const Color(0xFFA8B820);
      case 'normal':
        return const Color(0xFFA8A878);
      case 'flying':
        return const Color(0xFFA890F0);
      case 'fairy':
        return const Color(0xFFEE99AC);
      case 'psychic':
        return const Color(0xFFF85888);
      case 'rock':
        return const Color(0xFFB8A038);
      case 'ground':
        return const Color(0xFFE0C068);
      default:
        return const Color(0xFF705898);
    }
  }
}
