// lib/features/organisation_management/widgets/org_levels_field.dart
//
// The create/edit organisation form is institution-agnostic. Different org types
// organise learners differently — a school has grade levels, a university has
// degree programs, a coaching has batches, a private tutor teaches a free mix of
// grades AND higher-ed. This file holds:
//   • OrgTypeProfile  — how the generic "levels / programs" field, the head label
//                       and the accreditation field should read per org type.
//   • kOrgTypes       — the single source of truth for the type dropdown.
//   • OrgLevelsField  — a reusable widget: freeform "add chip" input + type-aware
//                       quick-add suggestions. Optional; works for every type.
import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../super_admin/widgets/sa_widgets.dart';

/// Per-type labels/hints/suggestions for the adaptive parts of the org form.
class OrgTypeProfile {
  final String levelsLabel; // e.g. "Grade Levels", "Degree Programs"
  final String levelsHelp; // one-line helper under the label
  final String addHint; // placeholder for the freeform add field
  final List<String> suggestions; // type-aware quick-add chips
  final String headLabel; // e.g. "Principal", "Director", "Your name"
  final String headHint;
  final String accreditationLabel; // e.g. "Board / Accreditation", "Qualification"
  final String accreditationHint;

  const OrgTypeProfile({
    required this.levelsLabel,
    required this.levelsHelp,
    required this.addHint,
    required this.suggestions,
    required this.headLabel,
    required this.headHint,
    required this.accreditationLabel,
    required this.accreditationHint,
  });
}

/// The org-type dropdown values — must match the backend `org_type` values.
const List<String> kOrgTypes = [
  'School',
  'College',
  'University',
  'Coaching',
  'Tutor',
  'Institute',
  'Other',
];

const Map<String, OrgTypeProfile> _kProfiles = {
  'School': OrgTypeProfile(
    levelsLabel: 'Grade Levels',
    levelsHelp: 'The grades this school teaches.',
    addHint: 'Add a grade (e.g. Grade 6)',
    suggestions: [
      'Pre-K', 'KG', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
      'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12',
    ],
    headLabel: 'Principal',
    headHint: 'Principal name',
    accreditationLabel: 'Board / Accreditation',
    accreditationHint: 'CBSE, ICSE, IB, State Board…',
  ),
  'College': OrgTypeProfile(
    levelsLabel: 'Streams / Programs',
    levelsHelp: 'The streams or programs offered.',
    addHint: 'Add a stream / program',
    suggestions: ['Science', 'Commerce', 'Arts', 'Engineering', 'B.A.', 'B.Sc.', 'B.Com', 'BBA', 'BCA'],
    headLabel: 'Principal / Dean',
    headHint: 'Principal / Dean name',
    accreditationLabel: 'Affiliation / Accreditation',
    accreditationHint: 'UGC, AICTE, NAAC, affiliating university…',
  ),
  'University': OrgTypeProfile(
    levelsLabel: 'Degree Programs',
    levelsHelp: 'The degree programs offered (no school grades).',
    addHint: 'Add a program (e.g. B.Tech)',
    suggestions: ['Undergraduate', 'Postgraduate', 'Diploma', 'PhD', 'B.Tech', 'M.Tech', 'MBA', 'M.Sc.'],
    headLabel: 'Director / Vice-Chancellor',
    headHint: 'Director / VC name',
    accreditationLabel: 'Accreditation',
    accreditationHint: 'UGC, NAAC, NBA…',
  ),
  'Coaching': OrgTypeProfile(
    levelsLabel: 'Batches / Courses',
    levelsHelp: 'The batches or exam courses offered.',
    addHint: 'Add a batch / course',
    suggestions: ['JEE', 'NEET', 'UPSC', 'Foundation', 'Class 9', 'Class 10', 'Class 11', 'Class 12', 'Boards'],
    headLabel: 'Director',
    headHint: 'Director name',
    accreditationLabel: 'Affiliation',
    accreditationHint: 'Optional',
  ),
  'Tutor': OrgTypeProfile(
    levelsLabel: 'What you teach',
    levelsHelp: 'Mix grades and subjects freely — e.g. Grade 9 Maths AND University Physics.',
    addHint: 'Add a subject / level',
    suggestions: [
      'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12',
      'A-Level', 'University', 'Maths', 'Science', 'English',
    ],
    headLabel: 'Your name',
    headHint: 'Your name',
    accreditationLabel: 'Qualification',
    accreditationHint: 'e.g. M.Sc. Maths (optional)',
  ),
  'Institute': OrgTypeProfile(
    levelsLabel: 'Courses / Programs',
    levelsHelp: 'The courses or programs offered.',
    addHint: 'Add a course / program',
    suggestions: ['Certificate', 'Diploma', 'Vocational', 'Skill Training', 'Language'],
    headLabel: 'Director',
    headHint: 'Director name',
    accreditationLabel: 'Accreditation',
    accreditationHint: 'Optional',
  ),
  'Other': OrgTypeProfile(
    levelsLabel: 'Levels / Programs',
    levelsHelp: 'What this organisation offers.',
    addHint: 'Add a level / program',
    suggestions: [],
    headLabel: 'Head / Owner',
    headHint: 'Head / owner name',
    accreditationLabel: 'Accreditation',
    accreditationHint: 'Optional',
  ),
};

/// Returns the profile for an org type, falling back to a generic one.
OrgTypeProfile orgProfileFor(String? type) => _kProfiles[type] ?? _kProfiles['Other']!;

/// A generic, type-adaptive "levels / programs offered" editor: a freeform
/// add-chip input plus type-aware quick-add suggestions. Always optional.
class OrgLevelsField extends StatefulWidget {
  final List<String> values;
  final OrgTypeProfile profile;
  final ValueChanged<List<String>> onChanged;

  const OrgLevelsField({
    super.key,
    required this.values,
    required this.profile,
    required this.onChanged,
  });

  @override
  State<OrgLevelsField> createState() => _OrgLevelsFieldState();
}

class _OrgLevelsFieldState extends State<OrgLevelsField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final v = raw.trim();
    _controller.clear();
    if (v.isEmpty) return;
    if (widget.values.any((e) => e.toLowerCase() == v.toLowerCase())) return;
    widget.onChanged([...widget.values, v]);
  }

  void _remove(String v) =>
      widget.onChanged(widget.values.where((e) => e != v).toList());

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final remaining = p.suggestions
        .where((s) => !widget.values.any((e) => e.toLowerCase() == s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${p.levelsLabel}  (optional)', style: Sa.value),
        const SizedBox(height: 2),
        Text(p.levelsHelp, style: Sa.label),
        const SizedBox(height: Sa.gap),

        // Selected values as deletable green chips.
        if (widget.values.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.values
                .map((v) => Chip(
                      label: Text(v,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5)),
                      backgroundColor: AppTheme.greenPrimary,
                      deleteIconColor: Colors.white,
                      onDeleted: () => _remove(v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: Sa.gap),
        ],

        // Freeform add row.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: _add,
                decoration: InputDecoration(
                  hintText: p.addHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _add(_controller.text),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.greenPrimary,
                  side: const BorderSide(color: AppTheme.greenPrimary),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadius8),
                ),
              ),
            ),
          ],
        ),

        // Type-aware quick-add suggestions.
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: Sa.gap),
          Text('Quick add', style: Sa.label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: remaining
                .map((s) => ActionChip(
                      label: Text(s,
                          style: const TextStyle(
                              color: AppTheme.neutral700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5)),
                      avatar: const Icon(Icons.add,
                          size: 15, color: AppTheme.greenPrimary),
                      backgroundColor: AppTheme.green50,
                      side: BorderSide(
                          color: AppTheme.greenPrimary.withValues(alpha: 0.3)),
                      onPressed: () => _add(s),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
