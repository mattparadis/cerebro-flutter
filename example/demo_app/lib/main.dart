import 'package:flutter/material.dart';

import 'app.dart';
import 'router.dart';

void main() {
  runApp(DemoApp(router: buildRouter(), themeMode: ThemeMode.system));
}
