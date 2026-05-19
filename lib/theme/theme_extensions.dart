import 'package:flutter/material.dart';

extension AppContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme   get text   => Theme.of(this).textTheme;
}
