import '../core/failure.dart';
import '../domain/delivery_order.dart';
import '../domain/pos_order.dart';
import 'app_localizations.dart';

/// Status words, payment methods, roles and failure kinds are CODES on the
/// wire and in the domain classes; these are the ONE place that turns them
/// into words for the reader (docs/I18N.md rule 6). The switches are
/// exhaustive on purpose: adding an enum value is a compile error here until
/// it has a label in every language.
extension StatusLabels on AppLocalizations {
  /// POS order status (`new`, `in_billing`, `sent_to_kitchen`, …).
  String posStatusLabel(PosStatus s) => switch (s) {
    PosStatus.fresh => statusNew,
    PosStatus.inBilling => statusInBilling,
    PosStatus.sentToKitchen => statusSentToKitchen,
    PosStatus.ready => statusReady,
    PosStatus.awaitingPayment => statusAwaitingPayment,
    PosStatus.paid => statusPaid,
    PosStatus.delivered => statusServed,
    PosStatus.cancelled => statusCancelled,
  };

  /// Marketplace delivery state (`placed`, `accepted`, `packed`, `out`, …).
  String deliveryStatusLabel(DeliveryStatus s) => switch (s) {
    DeliveryStatus.placed => deliveryStatusPlaced,
    DeliveryStatus.accepted => deliveryStatusAccepted,
    DeliveryStatus.packed => deliveryStatusPacked,
    DeliveryStatus.out => deliveryStatusOut,
    DeliveryStatus.delivered => deliveryStatusDelivered,
    DeliveryStatus.cancelled => deliveryStatusCancelled,
  };

  String inboxTabLabel(InboxTab t) => switch (t) {
    InboxTab.fresh => inboxTabNew,
    InboxTab.preparing => inboxTabPreparing,
    InboxTab.ready => inboxTabReady,
    InboxTab.past => inboxTabPast,
  };

  String paymentMethodLabel(PaymentMethod m) => switch (m) {
    PaymentMethod.cash => paymentMethodCash,
    PaymentMethod.upi => paymentMethodUpi,
    PaymentMethod.card => paymentMethodCard,
  };

  String serviceTypeLabel(ServiceType t) => switch (t) {
    ServiceType.dineIn => serviceDineIn,
    ServiceType.takeaway => serviceTakeaway,
    ServiceType.delivery => serviceDelivery,
  };

  String serviceTypeHint(ServiceType t) => switch (t) {
    ServiceType.dineIn => serviceDineInHint,
    ServiceType.takeaway => serviceTakeawayHint,
    ServiceType.delivery => serviceDeliveryHint,
  };

  /// Title of the failure view for a [FailureKind].
  String failureKindTitle(FailureKind k) => switch (k) {
    FailureKind.offline => failureTitleOffline,
    FailureKind.forbidden => failureTitleForbidden,
    FailureKind.notReady => failureTitleNotReady,
    FailureKind.auth => failureTitleAuth,
    FailureKind.conflict ||
    FailureKind.rejected ||
    FailureKind.unknown => failureTitleOther,
  };

  /// A role by its `roles.slug`. A slug this build does not know yet shows
  /// [fallback] (the server's `roles.name`), then the slug itself, so a role
  /// added on the server never renders blank.
  String roleLabel(String slug, {String? fallback}) {
    final known = switch (slug) {
      'org_owner' => roleOrgOwner,
      'org_admin' => roleOrgAdmin,
      'manager' => roleManager,
      'location_manager' => roleLocationManager,
      'operations_manager' => roleOperationsManager,
      'biller' => roleBiller,
      'captain' => roleCaptain,
      'staff_user' => roleStaff,
      'kitchen' => roleKitchen,
      'viewer' => roleViewer,
      'business_manager' => roleBusinessManager,
      'finance_manager' => roleFinanceManager,
      'accountant' => roleAccountant,
      'hr_manager' => roleHrManager,
      'marketing_manager' => roleMarketingManager,
      'inventory_manager' => roleInventoryManager,
      'procurement_manager' => roleProcurementManager,
      'support_user' => roleSupportUser,
      'analyst' => roleAnalyst,
      _ => null,
    };
    if (known != null) return known;
    final name = fallback?.trim();
    return (name != null && name.isNotEmpty) ? name : slug;
  }
}
