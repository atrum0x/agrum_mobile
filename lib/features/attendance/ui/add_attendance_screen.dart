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

// Compact type scale for this form
const _text = TextStyle(fontSize: 14);
const _muted = TextStyle(fontSize: 13, color: AppColors.mutedForeground);

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
              const Text('Add Attendance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
                        description: Text(_error!, style: _text),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (source.cacheInfo == null)
                      ShadAlert(
                        icon: const Icon(LucideIcons.cloudOff),
                        description: const Text(AttendanceMessages.noSiteData, style: _text),
                      )
                    else ...[
                      _Field(
                        label: 'Working Site',
                        child: _Select<String>(
                          key: ValueKey('site-$siteId'),
                          value: siteId,
                          placeholder: 'Select a site',
                          options: {for (final e in source.estates) e.id: '${e.id} – ${e.name}'},
                          onChanged: (v) => setState(() {
                            _siteId = v;
                            _siteChosen = true;
                            _workType = null;
                            _cpCode = null;
                            _cpChosen = false;
                          }),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Work Type',
                              child: _Select<String>(
                                key: ValueKey('wt-$siteId-$workType'),
                                value: workType,
                                enabled: site != null,
                                placeholder: 'Select',
                                options: {for (final wt in workTypes) wt.workType: wt.workType},
                                onChanged: (v) => setState(() => _workType = v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Collection Point',
                              child: _Select<String>(
                                key: ValueKey('cp-$siteId-$cpCode'),
                                value: cpCode,
                                enabled: site != null,
                                placeholder: 'Select',
                                options: {
                                  for (final cp in collectionPoints)
                                    cp.cpCode:
                                        cp.name == null || cp.name!.isEmpty ? cp.cpCode : '${cp.cpCode} – ${cp.name}',
                                },
                                onChanged: (v) => setState(() {
                                  _cpCode = v;
                                  _cpChosen = true;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (site != null && lists != null && (workTypes.isEmpty || collectionPoints.isEmpty))
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(AttendanceMessages.siteSetup,
                              style: TextStyle(fontSize: 13, color: AppColors.destructive)),
                        ),
                      _Field(
                        label: 'Workers present',
                        child: ShadInput(
                          placeholder: const Text('Search EMP No or name'),
                          leading: const Icon(LucideIcons.search, size: 18, color: AppColors.mutedForeground),
                          style: _text,
                          onChanged: (v) => setState(() => _search = v),
                        ),
                      ),
                      Text(
                        _selected.isEmpty ? 'Tick the workers present' : '${_selected.length} selected',
                        style: _selected.isEmpty
                            ? _muted
                            : const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              if (source.cacheInfo != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: selectedWorkers.isEmpty && available.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              term.isEmpty ? 'No more workers to mark today.' : 'No workers match "$_search".',
                              style: _muted,
                            ),
                          ),
                        )
                      // Ticked workers stay on top, in tick order, whatever the search
                      : SliverList.builder(
                          itemCount: selectedWorkers.length + available.length,
                          itemBuilder: (context, i) {
                            final ticked = i < selectedWorkers.length;
                            final w = ticked ? selectedWorkers[i] : available[i - selectedWorkers.length];
                            final otherSite = site != null && isOtherSiteWorker(w, site.id);
                            final allowed = ticked || !otherSite || profile.canRecordOtherSite;
                            return _WorkerRow(
                              worker: w,
                              ticked: ticked,
                              category: ticked
                                  ? _selected[w.employeeCode]
                                  : AttendanceCategory.fromCode(w.defaultCategory),
                              note: otherSite ? 'Default site ${w.defaultEstateId}' : null,
                              allowed: allowed,
                              onCategory: (c) => setState(() => _selected[w.employeeCode] = c),
                              onTap: () {
                                if (ticked) {
                                  setState(() => _selected.remove(w.employeeCode));
                                  return;
                                }
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
            height: 48,
            width: double.infinity,
            enabled: !_saving && source.cacheInfo != null,
            gradient: AppColors.headerGradient,
            shadows: AppColors.buttonShadows,
            onPressed: submit,
            child: Text(
              _selected.isEmpty ? 'Submit' : 'Submit (${_selected.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.3),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          placeholder: Text(placeholder, style: _muted),
          options: [
            for (final entry in options.entries)
              ShadOption<T>(value: entry.key, child: Text(entry.value, style: _text)),
          ],
          selectedOptionBuilder: (context, v) =>
              Text(options[v] ?? '$v', style: _text, overflow: TextOverflow.ellipsis),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        );
      },
    );
  }
}

/// One worker in the list: tick box, name and EMP No, and the category badge.
/// On a ticked worker the badge opens a menu to change the category (AT-08).
class _WorkerRow extends StatelessWidget {
  const _WorkerRow({
    required this.worker,
    required this.ticked,
    required this.category,
    required this.note,
    required this.allowed,
    required this.onCategory,
    required this.onTap,
  });

  final CachedWorker worker;
  final bool ticked;
  final AttendanceCategory? category;
  final String? note;
  final bool allowed;
  final ValueChanged<AttendanceCategory> onCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [worker.employeeCode, ?note].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.muted))),
        child: Row(
          children: [
            ShadCheckbox(value: ticked, enabled: allowed, onChanged: (_) => onTap()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.fullName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: allowed ? AppColors.foreground : AppColors.mutedForeground,
                    ),
                  ),
                  Text(details, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (ticked)
              PopupMenuButton<AttendanceCategory>(
                tooltip: 'Change category',
                initialValue: category,
                onSelected: onCategory,
                itemBuilder: (context) => [
                  for (final c in AttendanceCategory.values)
                    PopupMenuItem(value: c, height: 40, child: Text(c.label, style: _text)),
                ],
                child: _CategoryBadge(category: category, editable: true),
              )
            else if (category != null)
              _CategoryBadge(category: category, editable: false),
          ],
        ),
      ),
    );
  }
}

/// Small pill with the category; Regular in green, the others in grey, a missing one in red.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.editable});

  final AttendanceCategory? category;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (category) {
      null => (AppColors.destructive.withValues(alpha: 0.1), AppColors.destructive),
      AttendanceCategory.regular => (AppColors.accent, AppColors.primary),
      _ => (AppColors.muted, AppColors.mutedForeground),
    };
    return Container(
      // Taller tap target than the pill itself
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 3, editable ? 6 : 10, 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category?.label ?? 'Category',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
            ),
            if (editable) ...[
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronDown, size: 14, color: foreground),
            ],
          ],
        ),
      ),
    );
  }
}
