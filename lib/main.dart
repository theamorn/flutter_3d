import 'package:flutter/material.dart';
import 'app/app_shell.dart';
import 'stac/stac_gpu_parsers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureStacInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppShell(),
    ),
  );
}
