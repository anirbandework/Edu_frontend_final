// lib/shared/widgets/feedback_dialog.dart
//
// "Give feedback" — available to every logged-in user from the top bar. Submits
// to the super-admin's feedback inbox. AppTheme only.
import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../services/feedback_service.dart';

Future<void> showFeedbackDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _FeedbackDialog());
}

const _types = <MapEntry<String, String>>[
  MapEntry('suggestion', 'Suggestion'),
  MapEntry('bug', 'Bug / problem'),
  MapEntry('complaint', 'Complaint'),
  MapEntry('appreciation', 'Appreciation'),
  MapEntry('other', 'Other'),
];

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _type = 'suggestion';
  int _rating = 0; // 0 = not rated
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _err = 'Please add a title and a message');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await FeedbackService.submit(
        title: _title.text.trim(),
        message: _message.text.trim(),
        feedbackType: _type,
        rating: _rating > 0 ? _rating : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Thanks for your feedback!'),
        backgroundColor: AppTheme.greenPrimary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.feedback_outlined, color: AppTheme.greenPrimary, size: AppTheme.iconMedium),
        SizedBox(width: 8),
        Text('Give feedback'),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type', isDense: true),
                items: _types
                    .map((t) => DropdownMenuItem(value: t.key, child: Text(t.value)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'suggestion'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                    labelText: 'Tell us more *', isDense: true, alignLabelWithHint: true),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Text('Rating',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.neutral600)),
                const SizedBox(width: 8),
                ...List.generate(5, (i) {
                  final filled = i < _rating;
                  return IconButton(
                    onPressed: () => setState(() => _rating = i + 1),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(filled ? Icons.star : Icons.star_border,
                        color: filled ? AppTheme.greenPrimary : AppTheme.neutral400, size: 22),
                  );
                }),
                if (_rating > 0)
                  TextButton(
                    onPressed: () => setState(() => _rating = 0),
                    child: const Text('Clear'),
                  ),
              ]),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(_err!, style: AppTheme.bodySmall.copyWith(color: AppTheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: AppTheme.iconSmall),
          label: Text(_saving ? 'Sending…' : 'Send'),
        ),
      ],
    );
  }
}
