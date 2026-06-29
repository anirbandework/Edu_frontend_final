import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/class_model.dart';
import '../../../super_admin/widgets/sa_widgets.dart';

class BulkUpdateCapacityDialog extends StatefulWidget {
  final List<String> selectedIds;
  final List<ClassModel> items;
  const BulkUpdateCapacityDialog({super.key, required this.selectedIds, required this.items});

  @override
  State<BulkUpdateCapacityDialog> createState() => _BulkUpdateCapacityDialogState();
}

class _BulkUpdateCapacityDialogState extends State<BulkUpdateCapacityDialog> {
  final Map<String, TextEditingController> maxCtrls = {};
  final Map<String, TextEditingController> curCtrls = {};

  @override
  void initState() {
    super.initState();
    for (final id in widget.selectedIds) {
      final m = widget.items.firstWhere((e) => e.id == id);
      maxCtrls[id] = TextEditingController(text: m.maximumStudents.toString());
      curCtrls[id] = TextEditingController(text: m.currentStudents.toString());
    }
  }

  @override
  void dispose() {
    for (final c in maxCtrls.values) {
      c.dispose();
    }
    for (final c in curCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final maxW = math.min(screen.width - 24, 520.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Sa.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: screen.height - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Flexible(child: _list()),
            _actions(context),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Sa.radius)),
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
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Sa.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bulk Update Capacity', style: Sa.headerTitle),
                const SizedBox(height: 2),
                Text(
                  '${widget.selectedIds.length} ${widget.selectedIds.length == 1 ? 'class' : 'classes'} selected',
                  style: Sa.headerSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: widget.selectedIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sa.gap),
      itemBuilder: (_, i) {
        final id = widget.selectedIds[i];
        final m = widget.items.firstWhere((e) => e.id == id);
        return _classCard(id, m);
      },
    );
  }

  Widget _classCard(String id, ClassModel m) {
    return SaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.class_outlined, size: 18, color: Sa.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.className,
                  style: Sa.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sa.gap),
          LayoutBuilder(
            builder: (context, c) {
              final maxField = _numField(maxCtrls[id]!, 'Max students');
              final curField = _numField(curCtrls[id]!, 'Current students');
              if (c.maxWidth < 360) {
                return Column(
                  children: [
                    maxField,
                    const SizedBox(height: Sa.gap),
                    curField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: maxField),
                  const SizedBox(width: Sa.gap),
                  Expanded(child: curField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: Sa.value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Sa.label,
        isDense: true,
        filled: true,
        fillColor: AppTheme.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius8,
          borderSide: BorderSide(color: Sa.stroke),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius8,
          borderSide: BorderSide(color: Sa.stroke),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.borderRadius8,
          borderSide: BorderSide(color: Sa.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
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
          const Spacer(),
          SaPrimaryButton(
            label: 'Apply',
            icon: Icons.check_rounded,
            onPressed: () {
              final updates = widget.selectedIds.map((id) {
                return {
                  'class_id': id,
                  'maximum_students': int.tryParse(maxCtrls[id]!.text) ?? 0,
                  'current_students': int.tryParse(curCtrls[id]!.text) ?? 0,
                };
              }).toList();
              Navigator.pop(context, updates);
            },
          ),
        ],
      ),
    );
  }
}
