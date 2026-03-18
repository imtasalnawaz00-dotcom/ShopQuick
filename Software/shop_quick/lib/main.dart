import 'package:flutter/material.dart';

import 'MyApplication.dart';
import 'services/DatabaseService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;
  runApp(const MyApplication());
}
