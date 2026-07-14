import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../models/student_mark.dart';
import '../../widgets/dialog_header.dart';

class ReviewMarksModal extends StatefulWidget {
  final List<StudentMark> marks;
  final int maxMark;
  final String extractionType;

  const ReviewMarksModal({
    super.key,
    required this.marks,
    required this.maxMark,
    required this.extractionType,
  });

  @override
  State<ReviewMarksModal> createState() => _ReviewMarksModalState();
}

class _ReviewMarksModalState extends State<ReviewMarksModal> {
  late List<_EditableMark> _editableMarks;
  final TextEditingController _bulkMarkController = TextEditingController();
  Set<int> _selectedIndices = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    final seen = <String>{};
    final deduped = <StudentMark>[];
    for (final m in widget.marks) {
      final reg = m.registrationNumber.trim();
      if (reg.isEmpty || seen.add(reg)) {
        deduped.add(m);
      }
    }
    _editableMarks = deduped
        .map((m) => _EditableMark(
              registrationNumber: TextEditingController(text: m.registrationNumber),
              studentName: TextEditingController(text: m.studentName ?? ''),
              mark: TextEditingController(text: _clampMark(m.mark)),
            ))
        .toList();
  }

  String _clampMark(String mark) {
    final val = double.tryParse(mark);
    if (val == null) return mark;
    final clamped = val.clamp(0, widget.maxMark.toDouble());
    return clamped.toStringAsFixed(clamped == clamped.roundToDouble() ? 0 : 1);
  }

  @override
  void dispose() {
    _bulkMarkController.dispose();
    for (final em in _editableMarks) {
      em.registrationNumber.dispose();
      em.studentName.dispose();
      em.mark.dispose();
    }
    super.dispose();
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      _selectedIndices = _selectAll
          ? List.generate(_editableMarks.length, (i) => i).toSet()
          : {};
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
      _selectAll = _selectedIndices.length == _editableMarks.length;
    });
  }

  void _deleteSelected() {
    if (_selectedIndices.isEmpty) return;
    setState(() {
      final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final i in sorted) {
        _editableMarks.removeAt(i);
      }
      _selectedIndices = {};
      _selectAll = _editableMarks.isNotEmpty && _selectedIndices.length == _editableMarks.length;
    });
  }

  void _applyBulkMark() {
    final val = double.tryParse(_bulkMarkController.text);
    if (val == null || val < 0 || val > widget.maxMark) return;
    final indices = _selectedIndices.isNotEmpty
        ? _selectedIndices
        : List.generate(_editableMarks.length, (i) => i).toSet();
    for (final i in indices) {
      _editableMarks[i].mark.text = val.toStringAsFixed(val == val.roundToDouble() ? 0 : 1);
    }
    setState(() {});
  }

  void _deleteRow(int index) {
    setState(() {
      _editableMarks.removeAt(index);
      _selectedIndices.remove(index);
      if (_selectedIndices.length > _editableMarks.length) {
        _selectedIndices = _selectedIndices.where((i) => i < _editableMarks.length).toSet();
      }
    });
  }

  void _confirm() {
    final confirmed = _editableMarks.map((em) {
      final markVal = double.tryParse(em.mark.text);
      final clamped = markVal != null ? markVal.clamp(0, widget.maxMark.toDouble()) : null;
      return StudentMark(
        registrationNumber: em.registrationNumber.text.trim(),
        studentName: em.studentName.text.trim().isEmpty ? null : em.studentName.text.trim(),
        mark: clamped?.toStringAsFixed(clamped == clamped.roundToDouble() ? 0 : 1) ?? 'N/A',
        subject: widget.marks.first.subject,
        extractedAt: DateTime.now(),
        extractionType: widget.extractionType,
        maxMark: widget.maxMark,
      );
    }).toList();
    Navigator.pop(context, confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(
            icon: Icons.verified_outlined,
            title: 'Verify Extracted Marks',
            subtitle: '${_editableMarks.length} records · Max ${widget.maxMark}',
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EduColors.royalBlueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bulkMarkController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Apply mark to ${_selectedIndices.isNotEmpty ? "selected" : "all"}...',
                          hintStyle: GoogleFonts.poppins(fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyBulkMark,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EduColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text('Apply', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (_selectedIndices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: EduColors.royalBlue),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedIndices.length} selected',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: EduColors.royalBlue),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_sweep, size: 16, color: EduColors.error),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.poppins(fontSize: 12, color: EduColors.error, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: _editableMarks.length,
              itemBuilder: (context, index) {
                final em = _editableMarks[index];
                final isSelected = _selectedIndices.contains(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: GestureDetector(
                          onTap: () => _toggleSelection(index),
                          child: isSelected
                              ? Icon(Icons.check_box, size: 18, color: EduColors.royalBlue)
                              : Icon(Icons.check_box_outline_blank, size: 18, color: EduColors.textLight),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: EduColors.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: em.registrationNumber,
                            style: GoogleFonts.poppins(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Reg No',
                              hintStyle: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: em.studentName,
                            style: GoogleFonts.poppins(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Name',
                              hintStyle: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 64,
                        height: 36,
                        child: TextField(
                          controller: em.mark,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Mark',
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: EduColors.error),
                        onPressed: () => _deleteRow(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: EduColors.cardBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleSelectAll,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectAll ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                            color: _selectAll ? EduColors.royalBlue : EduColors.textLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Select All',
                            style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _selectedIndices.isNotEmpty ? _deleteSelected : null,
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: Text(
                        'Delete (${_selectedIndices.length})',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EduColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: EduColors.cardBorder,
                        disabledForegroundColor: EduColors.textLight,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EduColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Add ${_editableMarks.length} ${_editableMarks.length == 1 ? 'Entry' : 'Entries'}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMark {
  final TextEditingController registrationNumber;
  final TextEditingController studentName;
  final TextEditingController mark;

  _EditableMark({
    required this.registrationNumber,
    required this.studentName,
    required this.mark,
  });
}
