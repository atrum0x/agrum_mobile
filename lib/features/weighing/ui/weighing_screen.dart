import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import '../../auth/state/auth_controller.dart';
import '../../sync/data/sync_status.dart';
import '../data/weight_row.dart';
import '../domain/weighing_rules.dart';
import '../state/weighing_providers.dart';

// Compact type scale, same as Add Attendance
const _text = TextStyle(fontSize: 14);
const _muted = TextStyle(fontSize: 13, color: AppColors.mutedForeground);
const _label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: AppColors.mutedForeground);

final _time = DateFormat('HH:mm');
final _date = DateFormat('dd/MM/yyyy');

/// FSD 2.7 Enter Weight Management, phone screen. Shows only the 2.7 fields, in order (D-13, TC-48):
/// scale status, worker search, worker name, site · collection point · work type, Entries Today,
/// the weight, Capture Weight / Manual Entry, Save, and the weighings waiting to send.
///
/// The scale (6) is not built yet (CL-06 open): it always shows as not connected, so weights are
/// entered manually by users granted Manual Entry.
class WeighingScreen extends ConsumerStatefulWidget {
  const WeighingScreen({super.key});

  @override
  ConsumerState<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends ConsumerState<WeighingScreen> {
  String? _attendanceId;
  String _search = '';
  EntryType? _entryType;
  String? _error;
  bool _saving = false;
  final _searchController = TextEditingController();
  final _weightController = TextEditingController();
  final _weightFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  void _clear() {
    _attendanceId = null;
    _search = '';
    _entryType = null;
    _error = null;
    _searchController.clear();
    _weightController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final sourceAsync = ref.watch(weighingSourceProvider);
    final source = sourceAsync.value;
    if (auth is! LoggedIn || source == null) {
      return sourceAsync.hasError
          ? Center(child: Text('${sourceAsync.error}', style: _muted))
          : const Center(child: CircularProgressIndicator());
    }
    final canManual = auth.session.profile.canEnterWeightManually;
    final worker = source.workers.where((w) => w.attendanceId == _attendanceId).firstOrNull;

    Future<void> save() async {
      final now = DateTime.now();
      final error = validateWeighing(
        phoneNow: now,
        cacheInfo: source.cacheInfo,
        worker: worker,
        weightText: _weightController.text,
        entryType: _entryType,
        canEnterManually: canManual,
      );
      setState(() => _error = error);
      if (error != null) return;

      setState(() => _saving = true);
      try {
        final row = await ref.read(weightRecorderProvider).record(
              worker: worker!,
              weightKg: parseWeight(_weightController.text)!,
              entryType: _entryType!,
              now: now,
            );
        if (!mounted || row == null) return;
        FocusManager.instance.primaryFocus?.unfocus();
        ShadToaster.of(this.context).show(ShadToast(
          description: Text(WeighingMessages.saved(row.employeeCode, row.provisionalSequence, row.weightKg)),
        ));
        // Ready for the next worker (2.7 step 7)
        setState(_clear);
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const _ScaleStatus(),
              const SizedBox(height: 16),
              if (source.cacheInfo == null)
                ShadAlert(
                  icon: const Icon(LucideIcons.cloudOff),
                  description: const Text(WeighingMessages.noSiteData, style: _text),
                )
              else if (worker == null)
                _WorkerPicker(
                  controller: _searchController,
                  search: _search,
                  workers: source.workers,
                  onSearch: (v) => setState(() => _search = v),
                  onPick: (w) => setState(() {
                    _attendanceId = w.attendanceId;
                    _error = null;
                  }),
                )
              else ...[
                _SelectedWorker(
                  worker: worker,
                  onChange: () => setState(() {
                    _clear();
                  }),
                ),
                const SizedBox(height: 16),
                _WeightDisplay(
                  controller: _weightController,
                  focusNode: _weightFocus,
                  manual: _entryType == EntryType.manual,
                  onChanged: () => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        height: 44,
                        // WE-07: needs a valid reading; the scale is not connected
                        enabled: false,
                        leading: const Icon(LucideIcons.scale, size: 18),
                        child: const Text('Capture Weight', style: _text),
                      ),
                    ),
                    // WE-08: only users granted Manual Entry see it
                    if (canManual) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShadButton.outline(
                          height: 44,
                          enabled: _entryType != EntryType.manual,
                          leading: const Icon(LucideIcons.keyboard, size: 18),
                          onPressed: () {
                            setState(() {
                              _entryType = EntryType.manual;
                              _error = null;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) => _weightFocus.requestFocus());
                          },
                          child: const Text('Manual Entry', style: _text),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!canManual) ...[
                  const SizedBox(height: 8),
                  const Text(WeighingMessages.noScaleReading, style: _muted),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.destructive)),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _WaitingLink(),
              ShadButton(
                height: 48,
                width: double.infinity,
                enabled: !_saving && worker != null,
                gradient: AppColors.headerGradient,
                shadows: AppColors.buttonShadows,
                onPressed: save,
                child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 2.7 item 1. Always "not connected" until the scale module exists (CL-06).
class _ScaleStatus extends StatelessWidget {
  const _ScaleStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(LucideIcons.bluetoothOff, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          const Expanded(child: Text('Scale not connected', style: _text)),
          ShadButton.ghost(
            height: 36,
            onPressed: () => ShadToaster.of(context)
                .show(const ShadToast(description: Text('Scale connection is not available yet.'))),
            child: const Text('Connect Scale', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// 2.7 item 2: search by EMP No or name, among today's weighable workers.
class _WorkerPicker extends StatelessWidget {
  const _WorkerPicker({
    required this.controller,
    required this.search,
    required this.workers,
    required this.onSearch,
    required this.onPick,
  });

  final TextEditingController controller;
  final String search;
  final List<WeighableWorker> workers;
  final ValueChanged<String> onSearch;
  final ValueChanged<WeighableWorker> onPick;

  @override
  Widget build(BuildContext context) {
    final term = search.trim().toLowerCase();
    final matches = workers
        .where((w) =>
            term.isEmpty || w.employeeCode.toLowerCase().contains(term) || w.fullName.toLowerCase().contains(term))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Worker', style: _label),
        const SizedBox(height: 4),
        ShadInput(
          controller: controller,
          placeholder: const Text('Search EMP No or name'),
          leading: const Icon(LucideIcons.search, size: 18, color: AppColors.mutedForeground),
          style: _text,
          onChanged: onSearch,
        ),
        const SizedBox(height: 4),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              term.isNotEmpty
                  ? 'No workers match "$search".'
                  : 'No workers to weigh today. Record attendance with a weighing work type first.',
              style: _muted,
            ),
          )
        else
          for (final w in matches)
            InkWell(
              onTap: () => onPick(w),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.muted))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('${w.employeeCode} · ${w.estateId} · ${w.cpCode}',
                              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                    _EntriesPill(worker: w),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// 2.7 items 3–5: worker name; site · collection point · work type; Entries Today.
class _SelectedWorker extends StatelessWidget {
  const _SelectedWorker({required this.worker, required this.onChange});

  final WeighableWorker worker;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final cp = worker.cpName == null || worker.cpName!.isEmpty ? worker.cpCode : '${worker.cpCode} – ${worker.cpName}';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${worker.fullName} (${worker.employeeCode})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${worker.estateId} · $cp · ${worker.workType}', style: _muted),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Entries Today ', style: _muted),
                    _EntriesPill(worker: worker),
                  ],
                ),
                if (worker.atLimit) ...[
                  const SizedBox(height: 6),
                  Text(WeighingMessages.limitReached(worker.dailyLimit),
                      style: const TextStyle(fontSize: 13, color: AppColors.destructive)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change worker',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.mutedForeground),
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}

/// "x of n", red at the daily limit (WE-04).
class _EntriesPill extends StatelessWidget {
  const _EntriesPill({required this.worker});

  final WeighableWorker worker;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = worker.atLimit
        ? (AppColors.destructive.withValues(alpha: 0.1), AppColors.destructive)
        : (AppColors.accent, AppColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text('${worker.entriesToday} of ${worker.dailyLimit}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
    );
  }
}

/// 2.7 item 6: the weight in large numbers; typed on a number keypad in Manual Entry.
class _WeightDisplay extends StatelessWidget {
  const _WeightDisplay({
    required this.controller,
    required this.focusNode,
    required this.manual,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool manual;
  final VoidCallback onChanged;

  static const _big = TextStyle(fontSize: 48, fontWeight: FontWeight.w600, height: 1.1, color: AppColors.foreground);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: manual ? AppColors.ring : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(manual ? 'Weight · Manual' : 'Weight', style: _label),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: manual
                    ? IntrinsicWidth(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: _big,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          // WE-06: at most 2 decimals
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?'))],
                          onChanged: (_) => onChanged(),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: TextStyle(color: AppColors.border),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      )
                    : const Text('0.00', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w600, height: 1.1, color: AppColors.border)),
              ),
              const SizedBox(width: 6),
              const Text('kg', style: TextStyle(fontSize: 18, color: AppColors.mutedForeground)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2.7 item 8: how many weighings are waiting to send; tap for the list with Sync Status.
class _WaitingLink extends ConsumerWidget {
  const _WaitingLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(weighingListProvider).value;
    final all = [...?list?.today, ...?list?.earlier];
    final waiting = all.where((r) => r.status == SyncStatus.waiting).length;
    final rejected = all.where((r) => r.status == SyncStatus.rejected).length;
    final text = [
      if (waiting > 0) '$waiting waiting to send',
      if (rejected > 0) '$rejected rejected',
      if (waiting == 0 && rejected == 0) '${list?.today.length ?? 0} weighings today',
    ].join(' · ');
    final color = rejected > 0
        ? AppColors.destructive
        : waiting > 0
            ? AppColors.pending
            : AppColors.mutedForeground;
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _WeighingListSheet(),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(LucideIcons.list, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// Today's weighings with Waiting / Sent / Rejected and the reason; saved weighings can't be changed.
class _WeighingListSheet extends ConsumerWidget {
  const _WeighingListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(weighingListProvider).value;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Weighings today, ${_date.format(DateTime.now())}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (list == null || (list.today.isEmpty && list.earlier.isEmpty))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No weighings recorded today on this phone.', style: _muted),
            )
          else ...[
            for (final row in list.today) _WeighingTile(row: row),
            if (list.earlier.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
                child: Text('Earlier days, not sent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              for (final row in list.earlier) _WeighingTile(row: row, showDate: true),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeighingTile extends StatelessWidget {
  const _WeighingTile({required this.row, this.showDate = false});

  final WeightRow row;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final at = row.weighedAt.toLocal();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.muted))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${row.fullName} (${row.employeeCode})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text('${formatKg(row.weightKg)} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weighing ${row.sequence} · ${row.entryType.label} · '
                  '${showDate ? '${_date.format(at)} ' : ''}${_time.format(at)}',
                  style: _muted,
                ),
              ),
              SyncStatusBadge(status: row.status),
            ],
          ),
          if (row.status == SyncStatus.rejected && row.reason != null) ...[
            const SizedBox(height: 4),
            Text(row.reason!, style: const TextStyle(fontSize: 13, color: AppColors.destructive)),
          ],
        ],
      ),
    );
  }
}
