import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../application/bill_settings_controller.dart';
import '../../core/time_format.dart';
import '../../domain/billing.dart';
import '../../domain/staff.dart';
import '../menu/panel.dart';
import '../pos/pos_widgets.dart' show BillLines;
import '../theme/staff_theme.dart';
import '../widgets/setting_rows.dart';
import '../widgets/state_views.dart';
import 'bill_settings_widgets.dart';

/// Bill & GST: the GST rate, the service charge, rounding and what is printed
/// on every bill (`org_bill_settings`). Owners and admins edit; managers and
/// billers see the same screen with every field switched off.
///
/// An example bill ("₹1,000 of food") is worked out from the draft with the
/// same [BillSummary] maths the POS uses, so what an owner sees here is what a
/// guest will be charged. Save is enabled only when something changed and
/// every field is valid.
class BillSettingsScreen extends StatefulWidget {
  const BillSettingsScreen({super.key});

  @override
  State<BillSettingsScreen> createState() => _BillSettingsScreenState();
}

class _BillSettingsScreenState extends State<BillSettingsScreen> {
  late final BillSettingsController _c;
  late final bool _canView;

  final _legalName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _fssai = TextEditingController();
  final _footer = TextEditingController();
  final _customGst = TextEditingController();
  final _service = TextEditingController();

  /// Errors show once a field has been left, not while it is being typed.
  final _focus = <BillField, FocusNode>{
    for (final f in BillField.values) f: FocusNode(),
  };
  final _touched = <BillField>{};
  BillSettings? _syncedFrom;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    final session = services.session;
    _canView = session.can(Capability.viewBillSettings);
    _c = BillSettingsController(
      repository: services.backend.billSettings,
      prefs: services.prefs,
      orgId: session.membership?.organization.id ?? '',
      canEdit: session.can(Capability.editBillSettings),
    )..addListener(_sync);
    for (final entry in _focus.entries) {
      entry.value.addListener(() {
        if (!entry.value.hasFocus && mounted) {
          setState(() => _touched.add(entry.key));
        }
      });
    }
    if (_canView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.load();
      });
    }
  }

  @override
  void dispose() {
    _c
      ..removeListener(_sync)
      ..dispose();
    for (final c in [
      _legalName,
      _address,
      _phone,
      _gstin,
      _fssai,
      _footer,
      _customGst,
      _service,
    ]) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Copies a freshly loaded or saved row into the text boxes.
  void _sync() {
    final saved = _c.saved;
    if (saved == null || identical(saved, _syncedFrom)) return;
    _syncedFrom = saved;
    _touched.clear();
    void put(TextEditingController c, String v) {
      if (c.text != v) c.text = v;
    }

    put(_legalName, _c.legalName);
    put(_address, _c.address);
    put(_phone, _c.phone);
    put(_gstin, _c.gstin);
    put(_fssai, _c.fssai);
    put(_footer, _c.footerNote);
    put(_customGst, _c.customGstText);
    put(_service, _c.serviceText);
  }

  String? _error(BillField f) => _touched.contains(f) ? _c.errors[f] : null;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final ok = await _c.save();
    if (ok && mounted) showDone(context, 'Bill settings saved.');
  }

  Future<void> _onBlockedPop() async {
    if (_c.saving) return;
    final leave = await confirmDiscard(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return PopScope(
          canPop: !_c.isDirty || _c.saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBlockedPop();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Bill & GST')),
            bottomNavigationBar: _c.saved != null && _c.canEdit
                ? _SaveBar(
                    controller: _c,
                    onSave: _save,
                    onReload: () => _c.load(force: true),
                  )
                : null,
            body: _body(context),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (!_canView) {
      return const EmptyView(
        icon: Icons.lock_outline_rounded,
        title: 'Not available for your role',
        message: 'Ask an owner or admin to look at the bill settings.',
      );
    }
    final saved = _c.saved;
    if (saved == null) {
      if (_c.loadFailure != null && !_c.loading) {
        return FailureView(
          failure: _c.loadFailure!,
          onRetry: () => _c.load(force: true),
        );
      }
      return const LoadingView(label: 'Loading bill settings…');
    }
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= Breakpoints.wide;
        final preview = _PreviewCard(controller: _c);
        if (wide) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _sections(context, includePreview: false),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 32),
                      child: preview,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // A form this size is built whole, not lazily: every field is
        // reachable by keyboard, screen reader and test.
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _sections(context, includePreview: true),
          ),
        );
      },
    );
  }

  List<Widget> _sections(BuildContext context, {required bool includePreview}) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final edit = _c.canEdit;
    final saved = _c.saved!;
    final cgst = formatPercent(_c.cgst);
    final sgst = formatPercent(_c.sgst);
    final serviceError = _error(BillField.service);
    return [
      if (!edit) ...[
        const NoticeBanner(
          icon: Icons.lock_outline_rounded,
          message: 'Only an owner or admin can change this.',
        ),
        const SizedBox(height: 12),
      ] else if (!saved.exists) ...[
        const NoticeBanner(
          message:
              'No bill settings are saved yet, so bills use the standard 5% '
              'GST. Change anything below, then save.',
        ),
        const SizedBox(height: 12),
      ],
      Panel(
        children: [
          Text('GST rate', style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Added to every bill, on the food and on the service charge.',
            style: text.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          ChoiceSegments<double>(
            options: [
              for (final p in gstPresets) (p, '${formatPercent(p)}%'),
              (-1, 'Custom'),
            ],
            selected: _c.customGst ? -1 : _c.selectedGstPreset,
            onChanged: edit
                ? (v) {
                    if (v < 0) {
                      _c.pickCustomGst();
                      _customGst.text = _c.customGstText;
                    } else {
                      _c.pickGstPreset(v);
                    }
                  }
                : null,
          ),
          if (_c.customGst) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('bill-custom-gst'),
              controller: _customGst,
              focusNode: _focus[BillField.customGst],
              enabled: edit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}([.,]\d?)?'),
                ),
              ],
              decoration: InputDecoration(
                labelText: 'GST rate',
                hintText: 'e.g. 12.5',
                suffixText: '%',
                errorText: _error(BillField.customGst),
              ),
              onChanged: _c.setCustomGstText,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.call_split_rounded, size: 18, color: t.inkSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CGST $cgst% + SGST $sgst%',
                  key: const Key('bill-gst-split'),
                  style: TextStyle(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bill-gstin'),
            controller: _gstin,
            focusNode: _focus[BillField.gstin],
            enabled: edit,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
              const UpperCaseFormatter(),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              labelText: 'GSTIN',
              hintText: '22AAAAA0000A1Z5',
              helperText: 'Printed on every bill',
              errorText: _error(BillField.gstin),
            ),
            onChanged: _c.setGstin,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Panel(
        padding: null,
        children: [
          SettingSwitchRow(
            key: const Key('bill-service-switch'),
            title: 'Service charge',
            subtitle: 'Added before GST. Staff can remove it from a bill at the final order.',
            value: _c.serviceOn,
            onChanged: edit
                ? (on) {
                    _c.setServiceOn(on);
                    _service.text = _c.serviceText;
                  }
                : null,
          ),
          if (_c.serviceOn) ...[
            const PanelDivider(indent: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChoiceSegments<double>(
                    options: [
                      for (final p in servicePresets)
                        (p, '${formatPercent(p)}%'),
                    ],
                    selected: _c.selectedServicePreset,
                    onChanged: edit
                        ? (p) {
                            _c.pickServicePreset(p);
                            _service.text = _c.serviceText;
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('bill-service-percent'),
                    controller: _service,
                    focusNode: _focus[BillField.service],
                    enabled: edit,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,2}([.,]\d{0,2})?'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Percentage',
                      hintText: 'e.g. 10',
                      suffixText: '%',
                      helperText: 'Up to 50%',
                      errorText: serviceError,
                    ),
                    onChanged: _c.setServiceText,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 20),
      Panel(
        padding: null,
        children: [
          SettingSwitchRow(
            key: const Key('bill-round-switch'),
            title: 'Round the final bill to the nearest rupee',
            subtitle: 'For example, ₹553.46 becomes ₹553.',
            value: _c.roundOff,
            onChanged: edit ? _c.setRoundOff : null,
          ),
        ],
      ),
      if (includePreview) ...[
        const SizedBox(height: 20),
        _PreviewCard(controller: _c),
      ],
      const PanelLabel('On the printed bill'),
      Panel(
        children: [
          TextField(
            key: const Key('bill-legal-name'),
            controller: _legalName,
            enabled: edit,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Legal name',
              hintText: 'Your registered business name',
              counterText: '',
            ),
            onChanged: _c.setLegalName,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bill-address'),
            controller: _address,
            enabled: edit,
            minLines: 2,
            maxLines: 4,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Address',
              alignLabelWithHint: true,
              counterText: '',
            ),
            onChanged: _c.setAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bill-phone'),
            controller: _phone,
            focusNode: _focus[BillField.phone],
            enabled: edit,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
              LengthLimitingTextInputFormatter(18),
            ],
            decoration: InputDecoration(
              labelText: 'Phone',
              errorText: _error(BillField.phone),
            ),
            onChanged: _c.setPhone,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bill-fssai'),
            controller: _fssai,
            focusNode: _focus[BillField.fssai],
            enabled: edit,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
            decoration: InputDecoration(
              labelText: 'FSSAI number',
              helperText: '14 digits',
              errorText: _error(BillField.fssai),
            ),
            onChanged: _c.setFssai,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bill-footer'),
            controller: _footer,
            enabled: edit,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Footer note',
              hintText: 'Thank you! Visit again.',
              counterText: '',
            ),
            onChanged: _c.setFooterNote,
          ),
        ],
      ),
    ];
  }
}

/// "Example: ₹1,000 of food" with the bill lines the draft would produce.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.controller});

  final BillSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('bill-preview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Example: ₹1,000 of food', style: text.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Changes as you edit the settings.',
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 10),
            BillLines(bill: controller.example, totalLabel: 'Guest pays'),
          ],
        ),
      ),
    );
  }
}

/// The sticky bar at the bottom: whether there is anything to save, the Save
/// button, and the reason when a save did not go through.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.controller,
    required this.onSave,
    required this.onReload,
  });

  final BillSettingsController controller;
  final VoidCallback onSave;
  final VoidCallback onReload;

  String _savedAt(String? updatedAt) {
    final at = DateTime.tryParse(updatedAt ?? '');
    if (at == null) return 'Saved.';
    final local = at.toLocal();
    final now = DateTime.now();
    final today =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return today
        ? 'Last saved at ${clockTime(local)}'
        : 'Last saved ${shortDay(local)}, ${clockTime(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final c = controller;
    final failure = c.saveFailure;

    final IconData icon;
    final Color color;
    final String message;
    if (c.stale) {
      icon = Icons.sync_problem_rounded;
      color = t.warning;
      message =
          'Someone else saved these settings while you were editing. '
          'Reload to see their changes. Your edits here will be replaced.';
    } else if (failure != null) {
      icon = Icons.error_outline_rounded;
      color = t.danger;
      message = failure.message;
    } else if (c.isDirty && !c.isValid) {
      icon = Icons.edit_note_rounded;
      color = t.warning;
      message = 'Fix the highlighted fields to save.';
    } else if (c.isDirty) {
      icon = Icons.edit_note_rounded;
      color = t.inkSecondary;
      message = 'You have changes that are not saved yet.';
    } else if (c.justSaved) {
      icon = Icons.check_circle_rounded;
      color = t.success;
      message = 'All changes saved.';
    } else if (c.saved?.exists ?? false) {
      icon = Icons.history_rounded;
      color = t.inkSecondary;
      message = _savedAt(c.saved?.updatedAt);
    } else {
      icon = Icons.info_outline_rounded;
      color = t.inkSecondary;
      message = 'Not saved yet.';
    }

    return Material(
      color: t.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(icon, size: 18, color: color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                message,
                                key: const Key('bill-save-status'),
                                style: TextStyle(
                                  color: t.ink,
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (c.stale)
                      FilledButton(
                        key: const Key('bill-reload'),
                        onPressed: onReload,
                        child: const Text('Reload'),
                      )
                    else
                      FilledButton(
                        key: const Key('bill-save'),
                        onPressed: c.canSave ? onSave : null,
                        child: c.saving
                            ? SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: t.onAccent,
                                ),
                              )
                            : const Text('Save changes'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
