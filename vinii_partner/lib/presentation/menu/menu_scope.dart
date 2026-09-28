import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../application/menu_editor.dart';

/// The Menu tab's shared controller for the active organization. Created on
/// first use and dropped on sign-out or organization switch.
MenuEditorController menuEditorOf(BuildContext context) {
  final services = AppScope.of(context);
  return services.feature(() => MenuEditorController(services.backend.menu));
}
