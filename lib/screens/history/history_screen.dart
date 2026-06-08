import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../models/extraction_session.dart';
import '../../models/student_mark.dart';
import '../../services/excel_service.dart';
import '../../utils/theme.dart';

enum _TimeFilter { all, today, weekly, month }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _TimeFilter _filter = _TimeFilter.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.offWhite,
      appBar: AppBar(
        title: Text('History', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, sp, _) {
          final sessions = _filteredSessions(sp.sessions);
          return Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: sessions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) =>
                            _buildSessionCard(sessions[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _buildFilterChip('All', _TimeFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Today', _TimeFilter.today),
          const SizedBox(width: 8),
          _buildFilterChip('Weekly', _TimeFilter.weekly),
          const SizedBox(width: 8),
          _buildFilterChip('Month', _TimeFilter.month),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _TimeFilter filter) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? EduColors.royalBlue : EduColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? EduColors.royalBlue : EduColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : EduColors.textMedium,
          ),
        ),
      ),
    );
  }

  List<ExtractionSession> _filteredSessions(List<ExtractionSession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sessions.where((s) {
      final created = s.createdAt;
      switch (_filter) {
        case _TimeFilter.all:
          return true;
        case _TimeFilter.today:
          final c = DateTime(created.year, created.month, created.day);
          return c.isAtSameMomentAs(today);
        case _TimeFilter.weekly:
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          return created.isAfter(weekStart.subtract(const Duration(seconds: 1)));
        case _TimeFilter.month:
          return created.year == now.year && created.month == now.month;
      }
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: EduColors.royalBlueLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 48, color: EduColors.royalBlue),
          ),
          const SizedBox(height: 20),
          Text(
            'No sessions found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: EduColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == _TimeFilter.today
                ? 'No sessions extracted today'
                : _filter == _TimeFilter.weekly
                    ? 'No sessions extracted this week'
                    : _filter == _TimeFilter.month
                        ? 'No sessions extracted this month'
                        : 'No sessions found',
            style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ExtractionSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSessionDetail(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: EduColors.royalBlueLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  session.markCount > 0 ? Icons.check_circle : Icons.document_scanner,
                  color: session.markCount > 0 ? Colors.green : EduColors.royalBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: EduColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.course} · ${session.markCount} students · ${_formatDate(session.createdAt)}',
                      style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: EduColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetail(ExtractionSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return _SessionDetailSheet(
            session: session,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SessionDetailSheet extends StatefulWidget {
  final ExtractionSession session;
  final ScrollController scrollController;

  const _SessionDetailSheet({
    required this.session,
    required this.scrollController,
  });

  @override
  State<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<_SessionDetailSheet> {
  final ExcelService _excelService = ExcelService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final marks = session.marks;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: EduColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EduColors.royalBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.document_scanner, color: EduColors.royalBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: EduColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.course} · ${session.extractionType} · Max: ${session.maxMark}',
                      style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Created ${_formatDate(session.createdAt)} · ${marks.length} student${marks.length != 1 ? 's' : ''}',
            style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight),
          ),
          const SizedBox(height: 16),
          if (marks.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 56, color: EduColors.textLight.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('No marks in this session', style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium)),
                    const SizedBox(height: 4),
                    Text('Process images or use voice entry to add marks', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight)),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: EduColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, size: 16, color: EduColors.royalBlue),
                        const SizedBox(width: 6),
                        Text('${marks.length} students', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildExportButton(marks, session),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(EduColors.surface),
                    columnSpacing: 24,
                    columns: [
                      DataColumn(label: Text('S/N', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight))),
                      DataColumn(label: Text('Reg No.', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight))),
                      DataColumn(label: Text('Name', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight))),
                      DataColumn(numeric: true, label: Text('Mark', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight))),
                      DataColumn(label: Text('%', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight))),
                    ],
                    rows: marks.map((m) {
                      final score = double.tryParse(m.mark);
                      final pct = score != null && session.maxMark > 0
                          ? (score / session.maxMark * 100).toStringAsFixed(0)
                          : '--';
                      return DataRow(cells: [
                        DataCell(Text('${marks.indexOf(m) + 1}', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium))),
                        DataCell(Text(m.registrationNumber, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: EduColors.textDark))),
                        DataCell(Text(m.studentName ?? '', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium))),
                        DataCell(Text(m.mark, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: EduColors.royalBlue))),
                        DataCell(Text('$pct%', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportButton(List<StudentMark> marks, ExtractionSession session) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : () => _exportSession(marks, session),
        icon: _isExporting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.file_download, size: 16),
        label: Text(
          _isExporting ? 'Exporting...' : 'Excel',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _exportSession(List<StudentMark> marks, ExtractionSession session) async {
    setState(() => _isExporting = true);
    try {
      final file = await _excelService.generateExcelFile(marks, session.name);
      await _excelService.shareExcelFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e', style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}