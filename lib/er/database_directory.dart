import 'dart:io';
import 'package:pixez/page/hello/setting/demo_mode.dart';
import 'package:sqflite/sqflite.dart';

Future<String> demoDatabaseDirectory() async {
  final base = await getDatabasesPath();
  if (!DemoMode.active) return base;
  return (await Directory('$base/demo').create(recursive: true)).path;
}
