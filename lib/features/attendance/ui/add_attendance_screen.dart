import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../auth/state/auth_controller.dart';
import '../../setup/data/setup_data.dart';
import '../data/attendance_row.dart';
import '../domain/attendance_rules.dart';
import '../state/attendance_providers.dart';

/// FSD 2.6 steps 2–7: one batch of workers at one site, work type and collection point.
class AddAttendanceScreen extends ConsumerStatefulWidget {
  const AddAttendanceScreen({super.key});

  @override
  ConsumerState<AddAttendanceScreen> createState() => _AddAttendanceScreenState();
}

class _AddAttendanceScreenState extends ConsumerState<AddAttendanceScreen> {
  String? _siteId;
  bool _siteChosen = false;
  String? _workType;
  String? _cpCode;

  /// Set once the user picks a collection point; until then it follows the workers' default.
  bool _cpChosen = false;

  /// Ticked workers in tick order, with the category for each (AT-08).
  final _selected = <String, AttendanceCategory?>{};
  String _search = '';
  String? _error;
  bool _saving = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final auth = ref.watch(authControllerProvider);
    final sourceAsync = ref.watch(attendanceFormSourceProvider);
    final source = sourceAsync.value;
    if (auth is! LoggedIn || source == null) {
      return sourceAsync.hasError
          ? Center(child: Text('${sourceAsync.error}', style: theme.textTheme.muted))
          : const Center(child: CircularProgressIndicator());
    }
    final profile = auth.session.profile;

    // Working Site: the supervisor's default site, or the only one they can see
    final siteId = _siteChosen
        ? _siteId
        : (source.estates.any((e) => e.id == source.cacheInfo?.defaultEstateId)
            ? source.cacheInfo!.defaultEstateId
            : (source.estates.length == 1 ? source.estates.single.id : null));
    final site = source.estates.where((e) => e.id == siteId).firstOrNull;
    final lists = siteId == null ? null : ref.watch(siteListsProvider(siteId)).value;
    final workTypes = lists?.workTypes ?? const <CachedWorkType>[];
    final collectionPoints = lists?.collectionPoints ?? const <CachedCollectionPoint>[];

    final workersByCode = {for (final w in source.workers) w.employeeCode: w};
    final selectedWorkers = [for (final code in _selected.keys) ?workersByCode[code]];
    final workType = _workType ?? (workTypes.length == 1 ? workTypes.single.workType : null);
    final cpCode = _cpChosen ? _cpCode : defaultCollectionPoint(collectionPoints, selectedWorkers);

    final term = _search.trim().toLowerCase();
    final available = source.available
        .where((w) => !_selected.containsKey(w.employeeCode))
        .where((w) =>
            term.isEmpty || w.employeeCode.toLowerCase().contains(term) || w.fullName.toLowerCase().contains(term))
        .toList();

    Future<void> submit() async {
      final now = DateTime.now();
      final batch = [for (final w in selectedWorkers) BatchWorker(w, _selected[w.employeeCode])];
      final error = validateBatch(
        phoneNow: now,
        cacheInfo: source.cacheInfo,
        site: site,
        siteWorkTypes: workTypes,
        siteCollectionPoints: collectionPoints,
        workType: workType,
        cpCode: cpCode,
        workers: batch,
        markedToday: source.markedToday,
        canRecordOtherSite: profile.canRecordOtherSite,
      );
      setState(() => _error = error);
      if (error != null) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        return;
      }

      final confirmed = await showShadDialog<bool>(
        context: context,
        builder: (context) => ShadDialog.alert(
          title: const Text('Submit attendance'),
          description: Text(AttendanceMessages.confirm(batch.length)),
          actions: [
            ShadButton.outline(
              height: 48,
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ShadButton(height: 48, child: const Text('Submit'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _saving = true);
      try {
        await ref.read(attendanceRecorderProvider).record(
              estateId: site!.id,
              workType: workType!,
              cpCode: cpCode!,
              workers: batch,
              now: now,
            );
        if (!mounted) return;
        ShadToaster.of(this.context).show(ShadToast(description: Text(AttendanceMessages.recorded(batch.length))));
        this.context.go('/attendance');
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                iconSize: 24,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.go('/attendance'),
              ),
              Text('Add Attendance', style: theme.textTheme.h4),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(
                  children: [
                    if (_error != null) ...[
                      ShadAlert.destructive(
                        icon: const Icon(LucideIcons.circleAlert),
                        description: Text(_error!, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (source.cacheInfo == null)
                      ShadAlert(
                        icon: const Icon(LucideIcons.cloudOff),
                        description: const Text(AttendanceMessages.noSiteData, style: TextStyle(fontSize: 16)),
                      )
                    else ...[
                      _Field(
                        label: 'Working Site',
                        child: _Select<String>(
                          key: ValueKey('site-$siteId'),
                          value: siteId,
                          placeholder: 'Select a site',
                          options: {for (final e in source.estates) e.id: '${e.name} (${e.id})'},
                          onChanged: (v) => setState(() {
                            _siteId = v;
                            _siteChosen = true;
                            _workType = null;
                            _cpCode = null;
                            _cpChosen = false;
                          }),
                        ),
                      ),
                      _Field(
                        label: 'Work Type',
                        child: _Select<String>(
                          key: ValueKey('wt-$siteId-$workType'),
                          value: workType,
                          enabled: site != null,
                          placeholder: 'Select a work type',
                          options: {for (final wt in workTypes) wt.workType: wt.workType},
                          onChanged: (v) => setState(() => _workType = v),
                        ),
                      ),
                      _Field(
                        label: 'Collection Point',
                        child: _Select<String>(
                          key: ValueKey('cp-$siteId-$cpCode'),
                          value: cpCode,
                          enabled: site != null,
                          placeholder: 'Select a collection point',
                          options: {
                            for (final cp in collectionPoints)
                              cp.cpCode: cp.name == null || cp.name!.isEmpty ? cp.cpCode : '${cp.name} (${cp.cpCode})',
                          },
                          onChanged: (v) => setState(() {
                            _cpCode = v;
                            _cpChosen = true;
                          }),
                        ),
                      ),
                      if (site != null && lists != null && (workTypes.isEmpty || collectionPoints.isEmpty))
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(AttendanceMessages.siteSetup,
                              style: TextStyle(fontSize: 16, color: AppColors.destructive)),
                        ),
                      const SizedBox(height: 4),
                      Text('Selected workers (${_selected.length})', style: theme.textTheme.large),
                      const SizedBox(height: 8),
                      if (selectedWorkers.isEmpty)
                        Text('Tick workers below.', style: theme.textTheme.muted)
                      else
                        for (final w in selectedWorkers)
                          _SelectedWorker(
                            worker: w,
                            category: _selected[w.employeeCode],
                            otherSite: site != null && isOtherSiteWorker(w, site.id),
                            onCategory: (c) => setState(() => _selected[w.employeeCode] = c),
                            onRemove: () => setState(() => _selected.remove(w.employeeCode)),
                          ),
                      const SizedBox(height: 16),
                      ShadInput(
                        placeholder: const Text('Search EMP No or name'),
                        leading: const Icon(LucideIcons.search, size: 20),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              if (source.cacheInfo != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  sliver: available.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              term.isEmpty ? 'No more workers to mark today.' : 'No workers match "$_search".',
                              style: theme.textTheme.muted,
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: available.length,
                          itemBuilder: (context, i) {
                            final w = available[i];
                            final otherSite = site != null && isOtherSiteWorker(w, site.id);
                            final allowed = !otherSite || profile.canRecordOtherSite;
                            return _WorkerOption(
                              worker: w,
                              note: otherSite ? 'Default site ${w.defaultEstateId}' : null,
                              allowed: allowed,
                              onTap: () {
                                if (!allowed) {
                                  // AT-06
                                  ShadToaster.of(context).show(ShadToast.destructive(
                                      description: Text(AttendanceMessages.otherSite(workerLabel(w)))));
                                  return;
                                }
                                setState(() => _selected[w.employeeCode] =
                                    AttendanceCategory.fromCode(w.defaultCategory));
                              },
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: ShadButton(
            height: 52,
            width: double.infinity,
            enabled: !_saving && source.cacheInfo != null,
            onPressed: submit,
            child: Text(
              _selected.isEmpty ? 'Submit' : 'Submit (${_selected.length})',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// A full-width ShadSelect. Rebuilt through its key when [value] changes outside it.
class _Select<T> extends StatelessWidget {
  const _Select({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.placeholder,
    this.enabled = true,
    this.width,
  });

  final T? value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String placeholder;
  final bool enabled;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth;
        return ShadSelect<T>(
          initialValue: options.containsKey(value) ? value : null,
          enabled: enabled && options.isNotEmpty,
          minWidth: w,
          maxWidth: w,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          placeholder: Text(placeholder, style: const TextStyle(fontSize: 16)),
          options: [
            for (final entry in options.entries)
              ShadOption<T>(value: entry.key, child: Text(entry.value, style: const TextStyle(fontSize: 16))),
          ],
          selectedOptionBuilder: (context, v) =>
              Text(options[v] ?? '$v', style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        );
      },
    );
  }
}

class _SelectedWorker extends StatelessWidget {
  const _SelectedWorker({
    required this.worker,
    required this.category,
    required this.otherSite,
    required this.onCategory,
    required this.onRemove,
  });

  final CachedWorker worker;
  final AttendanceCategory? category;
  final bool otherSite;
  final ValueChanged<AttendanceCategory> onCategory;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  otherSite ? '${worker.employeeCode} · Default site ${worker.defaultEstateId}' : worker.employeeCode,
                  style: theme.textTheme.muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Select<AttendanceCategory>(
            key: ValueKey('cat-${worker.employeeCode}-$category'),
            value: category,
            width: 136,
            placeholder: 'Category',
            options: {for (final c in AttendanceCategory.values) c: c.label},
            onChanged: onCategory,
          ),
          IconButton(
            tooltip: 'Remove',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _WorkerOption extends StatelessWidget {
  const _WorkerOption({required this.worker, required this.note, required this.allowed, required this.onTap});

  final CachedWorker worker;
  final String? note;
  final bool allowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final category = AttendanceCategory.fromCode(worker.defaultCategory)?.label;
    final details = [worker.employeeCode, ?category, ?note].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ShadCheckbox(value: false, enabled: allowed, onChanged: (_) => onTap()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: allowed ? AppColors.foreground : AppColors.mutedForeground,
                      ),
                    ),
                    Text(details, style: theme.textTheme.muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
