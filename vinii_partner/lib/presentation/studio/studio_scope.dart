import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../application/studio_controller.dart';
import '../menu/menu_scope.dart';

/// Storefront Studio's shared controller for the active organization. It
/// shares the Menu tab's controller, so both see the same menu.
StudioController studioOf(BuildContext context) {
  final services = AppScope.of(context);
  final menu = menuEditorOf(context);
  return services.feature(
    () => StudioController(
      org: services.session.membership!.organization,
      storefront: services.backend.storefront,
      pos: services.backend.pos,
      menu: menu,
    ),
  );
}
