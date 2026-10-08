import '../../application/team_controller.dart';
import '../../domain/staff.dart';
import '../../l10n/app_localizations.dart';

/// What a role can do, in the reader's language: "Can take payments, take
/// table orders and accept delivery orders." Built from the role's ability
/// CODES ([roleAbilities]) with one message per phrase and one ICU message
/// per sentence shape, so every language orders the list its own way. No
/// translated fragment is joined with ", " or " and " in code.
String roleSummaryText(AppLocalizations l, String roleSlug) {
  final said = roleAbilities(roleSlug);
  if (said.isEmpty) return l.teamSummaryNothing;
  final p = [for (final a in said.take(3)) l.roleAbilityPhrase(a)];
  if (said.length > 3) {
    return l.teamSummaryMore(first: p[0], second: p[1], third: p[2]);
  }
  return switch (p.length) {
    1 => l.teamSummaryOne(first: p[0]),
    2 => l.teamSummaryTwo(first: p[0], second: p[1]),
    _ => l.teamSummaryThree(first: p[0], second: p[1], third: p[2]),
  };
}

extension TeamTexts on AppLocalizations {
  /// One ability as a phrase that fits the summary sentences.
  String roleAbilityPhrase(RoleAbility a) => switch (a) {
    RoleAbility.manageTeam => teamAbilityManageTeam,
    RoleAbility.changeBillSettings => teamAbilityChangeBillSettings,
    RoleAbility.publishStorefront => teamAbilityPublishStorefront,
    RoleAbility.editStorefront => teamAbilityEditStorefront,
    RoleAbility.editMenu => teamAbilityEditMenu,
    RoleAbility.switchDishes => teamAbilitySwitchDishes,
    RoleAbility.changeStoreStatus => teamAbilityChangeStoreStatus,
    RoleAbility.waiveServiceCharge => teamAbilityWaiveServiceCharge,
    RoleAbility.takePayments => teamAbilityTakePayments,
    RoleAbility.takeTableOrders => teamAbilityTakeTableOrders,
    RoleAbility.acceptDeliveryOrders => teamAbilityAcceptDeliveryOrders,
    RoleAbility.markFoodReady => teamAbilityMarkFoodReady,
    RoleAbility.seeDeliveryOrders => teamAbilitySeeDeliveryOrders,
    RoleAbility.seeMenu => teamAbilitySeeMenu,
    RoleAbility.seeBillSettings => teamAbilitySeeBillSettings,
  };

  /// Why a team change is not allowed, in words.
  String teamBlockText(TeamBlock b) => switch (b) {
    TeamBlock.notAdmin => teamBlockNotAdmin,
    TeamBlock.selfRole => teamBlockSelfRole,
    TeamBlock.selfSuspend => teamBlockSelfSuspend,
    TeamBlock.lastAdmin => teamBlockLastAdmin,
  };
}
