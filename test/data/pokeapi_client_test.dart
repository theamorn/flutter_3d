import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_3d/data/pokemon.dart';

const _pikachu = {
  'id': 25, 'name': 'pikachu', 'height': 4, 'weight': 60,
  'types': [{'slot': 1, 'type': {'name': 'electric'}}],
  'stats': [
    {'base_stat': 35, 'stat': {'name': 'hp'}},
    {'base_stat': 55, 'stat': {'name': 'attack'}},
  ],
  'sprites': {'other': {'official-artwork': {'front_default': 'https://img/25.png'}}},
};

void main() {
  test('parses name, types, stats, artwork', () {
    final p = Pokemon.fromJson(_pikachu);
    expect(p.displayName, 'Pikachu');
    expect(p.types, ['electric']);
    expect(p.stats['hp'], 35);
    expect(p.artworkUrl, 'https://img/25.png');
  });

  test('fetch hits /pokemon/<id> and caches', () async {
    var calls = 0;
    final c = PokeApiClient(client: MockClient((req) async {
      calls++;
      expect(req.url.toString(), 'https://pokeapi.co/api/v2/pokemon/25');
      return http.Response(jsonEncode(_pikachu), 200);
    }));
    expect(await c.fetch(25), isA<PokemonLoaded>());
    await c.fetch(25);
    expect(calls, 1);
  });

  test('network error returns PokemonLoadFailure', () async {
    final c = PokeApiClient(client: MockClient((_) async => throw http.ClientException('offline')));
    expect(await c.fetch(25), isA<PokemonLoadFailure>());
  });

  test('HTTP 404 returns PokemonLoadFailure', () async {
    final c = PokeApiClient(client: MockClient((_) async => http.Response('nope', 404)));
    expect(await c.fetch(25), isA<PokemonLoadFailure>());
  });

  test('timeout returns PokemonLoadFailure', () async {
    final c = PokeApiClient(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) => Completer<http.Response>().future));
    expect(await c.fetch(25), isA<PokemonLoadFailure>());
  });

  test('missing artwork does not throw (empty url)', () {
    final j = Map<String, dynamic>.from(_pikachu)..['sprites'] = {};
    expect(Pokemon.fromJson(j).artworkUrl, '');
  });
}
