import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/class_model.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class AssignClassroomsDialog extends StatefulWidget {
  final List<String> selectedIds;
  final List<ClassModel> items;
  const AssignClassroomsDialog({super.key, required this.selectedIds, required this.items});

  @override
  State<AssignClassroomsDialog> createState() => _AssignClassroomsDialogState();
}

class _AssignClassroomsDialogState extends State<AssignClassroomsDialog> {
  final Map<String, TextEditingController> roomCtrls = {};

  @override
  void initState() {
    super.initState();
    for (final id in widget.selectedIds) {
      final m = widget.items.firstWhere((e) => e.id == id);
      roomCtrls[id] = TextEditingController(text: m.classroom ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in roomCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final map = <String, String?>{};
    for (final id in widget.selectedIds) {
      final v = roomCtrls[id]!.text.trim();
      map[id] = v.isEmpty ? null : v;
    }
    Navigator.pop(context, map);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = math.min(size.width - 24, 520.0);
    final maxH = size.height - 80;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
                boxShadow: [AppTheme.greenShadow],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppTheme.borderRadius12,
                    ),
                    child: const Icon(Icons.meeting_room_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: Sa.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Assign Classrooms',
                            style: Sa.headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.selectedIds.length} class${widget.selectedIds.length == 1 ? '' : 'es'} selected',
                          style: Sa.headerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: widget.selectedIds.length,
                separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
                itemBuilder: (_, i) {
                  final id = widget.selectedIds[i];
                  final m = widget.items.firstWhere((e) => e.id == id);
                  return _RoomField(
                    className: m.className,
                    controller: roomCtrls[id]!,
                  );
                },
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.neutral600,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sa.gapXs),
                  SaPrimaryButton(
                    label: 'Apply',
                    icon: Icons.check_rounded,
                    onPressed: _apply,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single class row: name label + a room input field, wrapped in a tinted
/// surface so the list reads as cards rather than dense list tiles.
class _RoomField extends StatelessWidget {
  final String className;
  final TextEditingController controller;
  const _RoomField({required this.className, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(Sa.radius),
        border: Border.all(color: Sa.stroke.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.class_outlined, size: 16, color: Sa.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(className,
                    style: Sa.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: Sa.gapXs),
          TextField(
            controller: controller,
            style: Sa.value,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Room (leave empty to clear)',
              labelStyle: Sa.label,
              floatingLabelStyle: TextStyle(color: Sa.accent),
              filled: true,
              fillColor: Sa.surface,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: AppTheme.borderRadius12,
                borderSide: BorderSide(color: Sa.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.borderRadius12,
                borderSide: BorderSide(color: Sa.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.borderRadius12,
                borderSide: BorderSide(color: Sa.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
