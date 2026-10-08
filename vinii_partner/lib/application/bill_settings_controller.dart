import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../data/local_prefs.dart';
import '../domain/billing.dart';

/// The GST rates the Bill & GST screen offers as one tap. Each sets CGST and
/// SGST to half, which is how GST is split on an Indian restaurant bill.
const gstPresets = [0.0, 5.0, 12.0, 18.0];

/// The service charge percentages offered as one tap.
const servicePresets = [5.0, 7.5, 10.0];

/// What is shown if switching the service charge ON has nothing to restore.
const defaultServiceCharge = 5.0;

/// The example bill on the screen is worked out for this much food (rupees).
const exampleFoodAmount = 1000;

double? parsePercent(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.'));

/// The Bill & GST screen's working copy: what the owner has typed so far,
/// whether it can be saved, and what the example bill looks like with it.
///
/// Nothing is written until [save]. The draft is checked field by field
/// ([errors]), compared with what the database holds ([isDirty]), and saved
/// against the version it was loaded from, so a screen that has gone stale
/// cannot overwrite someone else's save (it sets [stale] instead).
class BillSettingsController extends ChangeNotifier {
  BillSettingsController({
    required this.repository,
    required this.prefs,
    required this.orgId,
    required this.canEdit,
  });

  final BillSettingsRepository repository;
  final LocalPrefs prefs;
  final String orgId;

  /// Only owners and admins change these settings; everyone else sees them.
  final bool canEdit;

  // ── Loading and saving ─────────────────────────────────────────────────

  /// As the database holds it. Null until the first load answers.
  BillSettings? saved;
  AppFailure? loadFailure;
  bool loading = false;
  bool saving = false;

  /// The reason the last save did not go through, shown until the next edit.
  AppFailure? saveFailure;

  /// Someone else saved while this screen was open.
  bool stale = false;

  /// The last save went through and nothing has been edited since.
  bool justSaved = false;

  bool _disposed = false;

  Future<void> load({bool force = false}) async {
    if (loading || (saved != null && !force)) return;
    loading = true;
    loadFailure = null;
    _notify();
    try {
      final s = await repository.load();
      saved = s;
      stale = false;
      saveFailure = null;
      justSaved = false;
      _fill(s);
    } on AppFailure catch (e) {
      loadFailure = e;
    } catch (e) {
      loadFailure = asFailure(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  // ── The draft ──────────────────────────────────────────────────────────

  String legalName = '';
  String address = '';
  String phone = '';
  String gstin = '';
  String fssai = '';
  String footerNote = '';

  double sgst = BillCharges.defaults.sgstPercent;
  double cgst = BillCharges.defaults.cgstPercent;

  /// The owner chose "Custom" (or the saved rate is not one of the presets).
  bool customGst = false;
  String customGstText = '';

  bool serviceOn = false;

  /// The percentage as typed. Kept while the switch is OFF, so switching it
  /// back ON restores it.
  String serviceText = formatPercent(defaultServiceCharge);
  bool roundOff = true;

  void _fill(BillSettings s) {
    legalName = s.legalName;
    address = s.address;
    phone = s.phone;
    gstin = s.gstin;
    fssai = s.fssai;
    footerNote = s.footerNote;
    sgst = s.sgstPercent;
    cgst = s.cgstPercent;
    final even = (sgst - cgst).abs() < 0.0001;
    customGst = !(even && _isPreset(s.gstPercent));
    customGstText = formatPercent(s.gstPercent);
    roundOff = s.roundOff;
    serviceOn = s.serviceChargePercent > 0;
    if (serviceOn) {
      serviceText = formatPercent(s.serviceChargePercent);
      unawaited(prefs.setLastServiceCharge(orgId, s.serviceChargePercent));
    } else {
      serviceText = formatPercent(
        prefs.lastServiceCharge(orgId) ?? defaultServiceCharge,
      );
    }
  }

  static bool _isPreset(double total) =>
      gstPresets.any((p) => (p - total).abs() < 0.0001);

  double get gstTotal => sgst + cgst;

  /// The preset chip that is selected, or null when "Custom" is.
  double? get selectedGstPreset {
    if (customGst || (sgst - cgst).abs() >= 0.0001) return null;
    for (final p in gstPresets) {
      if ((p - gstTotal).abs() < 0.0001) return p;
    }
    return null;
  }

  double? get serviceValue => parsePercent(serviceText);

  /// The service preset that matches the typed percentage, if any.
  double? get selectedServicePreset {
    final v = serviceValue;
    if (!serviceOn || v == null) return null;
    for (final p in servicePresets) {
      if ((p - v).abs() < 0.0001) return p;
    }
    return null;
  }

  // ── Editing ────────────────────────────────────────────────────────────

  void _edited() {
    justSaved = false;
    saveFailure = null;
    _notify();
  }

  void setLegalName(String v) {
    legalName = v;
    _edited();
  }

  void setAddress(String v) {
    address = v;
    _edited();
  }

  void setPhone(String v) {
    phone = v;
    _edited();
  }

  void setGstin(String v) {
    gstin = v.toUpperCase();
    _edited();
  }

  void setFssai(String v) {
    fssai = v;
    _edited();
  }

  void setFooterNote(String v) {
    footerNote = v;
    _edited();
  }

  /// One tap on 0, 5, 12 or 18: CGST and SGST each get half.
  void pickGstPreset(double total) {
    sgst = total / 2;
    cgst = total / 2;
    customGst = false;
    customGstText = formatPercent(total);
    _edited();
  }

  void pickCustomGst() {
    customGst = true;
    customGstText = formatPercent(gstTotal);
    _edited();
  }

  void setCustomGstText(String v) {
    customGstText = v;
    final total = parsePercent(v);
    if (total != null && total >= 0 && total <= 100) {
      sgst = total / 2;
      cgst = total / 2;
    }
    _edited();
  }

  /// Switching OFF remembers the percentage; switching ON restores it.
  void setServiceOn(bool on) {
    if (on == serviceOn) return;
    if (on) {
      final typed = serviceValue;
      final remembered = prefs.lastServiceCharge(orgId);
      if (typed == null || typed <= 0) {
        serviceText = formatPercent(remembered ?? defaultServiceCharge);
      }
    } else {
      final v = serviceValue;
      if (v != null && v > 0) unawaited(prefs.setLastServiceCharge(orgId, v));
    }
    serviceOn = on;
    _edited();
  }

  void setServiceText(String v) {
    serviceText = v;
    _edited();
  }

  void pickServicePreset(double percent) {
    serviceText = formatPercent(percent);
    _edited();
  }

  void setRoundOff(bool on) {
    roundOff = on;
    _edited();
  }

  // ── Checking ───────────────────────────────────────────────────────────

  /// What is wrong, by field (the screen words each problem in the reader's
  /// language). Empty means the draft can be saved.
  Map<BillField, BillProblem> get errors {
    final out = <BillField, BillProblem>{};
    if (customGst) {
      final total = parsePercent(customGstText);
      final oneDecimal = RegExp(r'^\d{1,3}([.,]\d)?$')
          .hasMatch(customGstText.trim());
      if (total == null || total < 0 || total > 100 || !oneDecimal) {
        out[BillField.customGst] = BillProblem.customRate;
      }
    }
    final gstinError = gstinProblem(gstin);
    if (gstinError != null) out[BillField.gstin] = gstinError;
    if (serviceOn) {
      final v = serviceValue;
      if (v == null || v <= 0 || v > maxServiceChargePercent) {
        out[BillField.service] = BillProblem.servicePercent;
      }
    }
    final fssaiError = fssaiProblem(fssai);
    if (fssaiError != null) out[BillField.fssai] = fssaiError;
    final phoneError = billPhoneProblem(phone);
    if (phoneError != null) out[BillField.phone] = phoneError;
    return out;
  }

  bool get isValid => errors.isEmpty;

  /// The draft as settings. Fields that cannot be read yet fall back to what
  /// is saved, so the example bill keeps showing something sensible while
  /// someone is mid-way through typing.
  BillSettings get draft {
    final base = saved ?? BillSettings.defaults;
    final service = serviceOn
        ? (serviceValue ?? 0).clamp(0, maxServiceChargePercent)
        : 0;
    return BillSettings(
      legalName: legalName.trim(),
      address: address.trim(),
      gstin: gstin.trim().toUpperCase(),
      fssai: fssai.trim(),
      phone: phone.trim(),
      sgstPercent: sgst,
      cgstPercent: cgst,
      serviceChargePercent: service.toDouble(),
      roundOff: roundOff,
      footerNote: footerNote.trim(),
      updatedAt: base.updatedAt,
    );
  }

  bool get isDirty => saved != null && !draft.sameValuesAs(saved!);

  bool get canSave =>
      canEdit && saved != null && isDirty && isValid && !saving && !stale;

  /// The example bill: [exampleFoodAmount] rupees of food with the draft's
  /// rates.
  BillSummary get example => BillSummary.of([
    (unitPrice: exampleFoodAmount, qty: 1),
  ], charges: draft.charges);

  // ── Saving ─────────────────────────────────────────────────────────────

  /// Saves the draft. Returns true on success; on failure [saveFailure] says
  /// why (and [stale] is set when someone else saved first).
  Future<bool> save() async {
    if (!canSave) return false;
    saving = true;
    saveFailure = null;
    justSaved = false;
    _notify();
    try {
      final result = await repository.save(draft);
      saved = result;
      _fill(result);
      justSaved = true;
      return true;
    } on AppFailure catch (e) {
      saveFailure = e;
      stale = e.isConflict;
      return false;
    } catch (e) {
      saveFailure = asFailure(e);
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The fields that can have a problem.
enum BillField { customGst, gstin, service, fssai, phone }
