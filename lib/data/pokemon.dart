import 'dart:convert';
import 'package:http/http.dart' as http;

/// book_0 … book_5 show these Pokémon, in order.
const List<int> kBookPokemon = [1, 4, 7, 25, 133, 143];

// Tolerant JSON readers: a missing or oddly-typed key yields null / empty,
// never a throw. (`as Map<String, dynamic>?` would reject a `{}` literal,
// which is a Map<dynamic, dynamic>.)
Map? _map(Object? o) => o is Map ? o : null;
List _list(Object? o) => o is List ? o : const [];
String _str(Object? o) => o is String ? o : '';
int _int(Object? o) => o is num ? o.toInt() : 0;

class Pokemon {
  Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.stats,
    required this.artworkUrl,
    required this.heightDm,
    required this.weightHg,
  });

  final int id;
  final String name;
  final List<String> types;

  /// hp, attack, defense, special-attack, special-defense, speed.
  final Map<String, int> stats;

  /// sprites.other['official-artwork'].front_default, or '' when missing.
  final String artworkUrl;
  final int heightDm, weightHg;

  factory Pokemon.fromJson(Map<String, dynamic> j) => Pokemon(
        id: _int(j['id']),
        name: _str(j['name']),
        types: [
          for (final t in _list(j['types'])) _str(_map(_map(t)?['type'])?['name'])
        ],
        stats: {
          for (final s in _list(j['stats']))
            _str(_map(_map(s)?['stat'])?['name']): _int(_map(s)?['base_stat'])
        },
        artworkUrl: _str(_map(_map(_map(j['sprites'])?['other'])?['official-artwork'])?[
            'front_default']),
        heightDm: _int(j['height']),
        weightHg: _int(j['weight']),
      );

  /// "pikachu" → "Pikachu".
  String get displayName =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

sealed class PokemonResult {}

class PokemonLoaded extends PokemonResult {
  PokemonLoaded(this.pokemon);
  final Pokemon pokemon;
}

class PokemonLoadFailure extends PokemonResult {
  PokemonLoadFailure(this.message);
  final String message;
}

class PokeApiClient {
  PokeApiClient({http.Client? client, this.timeout = const Duration(seconds: 6)})
      : _client = client ?? http.Client();

  static const _base = 'https://pokeapi.co/api/v2';
  final http.Client _client;
  final Duration timeout;
  final Map<int, Pokemon> _cache = {};

  /// Never throws: offline, slow, non-200 and malformed responses all come
  /// back as [PokemonLoadFailure]. Successes are cached in memory.
  Future<PokemonResult> fetch(int id) async {
    final cached = _cache[id];
    if (cached != null) return PokemonLoaded(cached);
    try {
      final res = await _client.get(Uri.parse('$_base/pokemon/$id')).timeout(timeout);
      if (res.statusCode != 200) {
        return PokemonLoadFailure('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) {
        return PokemonLoadFailure('Unexpected response');
      }
      final p = Pokemon.fromJson(json);
      _cache[id] = p;
      return PokemonLoaded(p);
    } catch (e) {
      return PokemonLoadFailure('$e');
    }
  }
}
