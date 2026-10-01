import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../domain/pos_order.dart';

/// Tables of one floor section, in floor order.
class TableGroup {
  const TableGroup(this.name, this.tables);

  /// The section's name, or null for tables that belong to none.
  final String? name;
  final List<TableCode> tables;
}

/// The Table QR codes screen's state: every table with its code, grouped by
/// floor section, and issuing a code for a table.
///
/// Issuing and replacing go through the proposed `pos_issue_table_qr` (the
/// repository maps its absence to "not available yet"). Replacing a code is
/// destructive, so it must be asked for by name: the controller never
/// replaces one by accident.
class TableCodesController extends ChangeNotifier {
  TableCodesController({required this.repository, required this.canIssue});

  final TablesRepository repository;

  /// Only some roles may issue codes (`Capability.issueTableCodes`).
  final bool canIssue;

  List<TableCode>? tables;
  AppFailure? failure;
  bool loading = false;

  /// Tables whose code is being issued right now.
  final busy = <String>{};

  bool _disposed = false;

  Future<void> load({bool force = false}) async {
    if (loading || (tables != null && !force)) return;
    loading = true;
    failure = null;
    _notify();
    try {
      tables = await repository.list();
    } on AppFailure catch (e) {
      failure = e;
    } catch (e) {
      failure = asFailure(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Tables with a code, in use or not.
  List<TableCode> get withCodes =>
      (tables ?? const <TableCode>[]).where((t) => t.hasCode).toList();

  /// The tables a printed sheet should hold: coded and in use.
  List<TableCode> get printable => withCodes.where((t) => t.isActive).toList();

  /// Sections in the order the list came in. Tables with no section are one
  /// last group with a null name.
  List<TableGroup> get groups {
    final byName = <String?, List<TableCode>>{};
    for (final t in tables ?? const <TableCode>[]) {
      (byName[t.areaName] ??= []).add(t);
    }
    final named = [
      for (final e in byName.entries)
        if (e.key != null) TableGroup(e.key, e.value),
    ];
    final none = byName[null];
    return [...named, if (none != null) TableGroup(null, none)];
  }

  /// Gives a table its first code, or [replace]s the one it has.
  Future<TableCode> issue(TableCode table, {bool replace = false}) async {
    if (!canIssue) {
      throw const AppFailure(
        'Only an admin or manager can issue table codes.',
        kind: FailureKind.forbidden,
      );
    }
    if (busy.contains(table.id)) {
      throw const AppFailure(
        'Already working on it…',
        kind: FailureKind.rejected,
      );
    }
    busy.add(table.id);
    _notify();
    try {
      final saved = await repository.issueCode(table, replace: replace);
      tables = [
        for (final t in tables ?? const <TableCode>[])
          t.id == saved.id ? saved : t,
      ];
      return saved;
    } finally {
      busy.remove(table.id);
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
