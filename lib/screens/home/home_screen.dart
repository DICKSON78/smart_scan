import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:go_router/go_router.dart';
import 'package:cuberto_bottom_bar/cuberto_bottom_bar.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/result_provider.dart';
import '../../providers/audit_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/student_mark.dart';
import '../../models/extraction_session.dart';
import '../../services/hybrid_ocr_service.dart';
import '../../services/image_processor.dart';
import '../../services/excel_service.dart';
import '../../services/logger_service.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/teacher/teacher_management_screen.dart';
import '../../utils/theme.dart';
import '../../utils/voice_parser.dart';
import '../../widgets/dialog_header.dart';
import 'review_marks_modal.dart';
import 'image_uploader.dart';
import 'live_scanner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class VoiceEntryResult {
  final int position;
  final String label;
  final double mark;
  final bool success;
  final String? reason;
  final String? registrationNumber;
  final String? studentName;
  VoiceEntryResult({
    required this.position,
    required this.label,
    required this.mark,
    required this.success,
    this.reason,
    this.registrationNumber,
    this.studentName,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, bool>(
      selector: (_, a) => a.isAdmin,
      builder: (context, isAdmin, _) {
        final adminTabs = [
          _TabConfig(Icons.home_outlined, 'Home', HomeTabContent(onNavigateToHistory: () => setState(() => _selectedTab = 1))),
          _TabConfig(Icons.history_outlined, 'History', const HistoryScreen()),
          _TabConfig(Icons.people_outlined, 'Team', const TeacherManagementScreen()),
          _TabConfig(Icons.settings_outlined, 'Settings', const SettingsScreen()),
        ];
        final teacherTabs = [
          _TabConfig(Icons.home_outlined, 'Home', HomeTabContent(onNavigateToHistory: () => setState(() => _selectedTab = 1))),
          _TabConfig(Icons.history_outlined, 'History', const HistoryScreen()),
          _TabConfig(Icons.settings_outlined, 'Settings', const SettingsScreen()),
        ];
        final tabs = isAdmin ? adminTabs : teacherTabs;

        if (_selectedTab >= tabs.length) {
          _selectedTab = 0;
        }

        final tabData = tabs.map((t) => TabData(
          iconData: t.icon,
          title: t.title,
          tabColor: EduColors.royalBlue,
          tabGradient: null,
        )).toList();

        return Scaffold(
          backgroundColor: EduColors.offWhite,
          body: IndexedStack(
            index: _selectedTab,
            children: tabs.map((t) => t.screen).toList(),
          ),
          bottomNavigationBar: CubertoBottomBar(
            inactiveIconColor: EduColors.textLight,
            textColor: Colors.white,
            tabStyle: CubertoTabStyle.styleNormal,
            selectedTab: _selectedTab,
            tabs: tabData,
            onTabChangedListener: (position, title, color) {
              setState(() {
                _selectedTab = position;
              });
            },
          ),
        );
      },
    );
  }
}

class _TabConfig {
  final IconData icon;
  final String title;
  final Widget screen;
  const _TabConfig(this.icon, this.title, this.screen);
}

class HomeTabContent extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  const HomeTabContent({super.key, this.onNavigateToHistory});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  final HybridOcrService _hybridOcrService = HybridOcrService();
  final ExcelService _excelService = ExcelService();

  final List<File> _selectedImages = [];
  bool _isProcessing = false;
  bool _isExporting = false;
  List<StudentMark> _voiceClassList = [];
  bool _isParsingVoiceClassList = false;
  stt.SpeechToText? _speech;
  bool _voiceIsRecording = false;
  bool _voiceIsProcessing = false;
  String _voiceTranscribedText = '';
  String? _voiceErrorMsg;
  List<VoiceEntryResult> _voiceBatchResults = [];
  bool _speechAvailable = false;
  String _lastVoiceSessionId = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech!.initialize(
      onError: (e) => setState(() => _voiceErrorMsg = 'Speech error: ${e.errorMsg}'),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (_voiceIsRecording) _stopVoiceRecording();
        }
      },
    );
    if (!_speechAvailable && mounted) {
      setState(() => _voiceErrorMsg = 'Speech recognition not available on this device');
    }
  }

  @override
  void dispose() {
    _hybridOcrService.dispose();
    _speech?.stop();
    super.dispose();
  }


  Future<void> _processImages(ExtractionSession session) async {
    final authProvider = context.read<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final subject = session.course;
    final maxMark = session.maxMark;
    final extractionType = session.extractionType;

    if (_selectedImages.isEmpty) {
      _showSnack('Select files first');
      return;
    }

    if (authProvider.credits < 1) {
      GoRouter.of(context).push('/purchase');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (!mounted) { setState(() => _isProcessing = false); return; }

      final compressed = await ImageProcessor.compressImages(_selectedImages);

      final marks = await _hybridOcrService.extractMarksFromImages(
        compressed,
        subject: subject,
        maxMark: maxMark,
        extractionType: extractionType,
      );

      if (marks.isEmpty) {
        _showSnack('No marks could be extracted');
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) { setState(() => _isProcessing = false); return; }
      final confirmed = await showDialog<List<StudentMark>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReviewMarksModal(
          marks: marks,
          maxMark: maxMark,
          extractionType: extractionType,
        ),
      );

      if (confirmed != null && mounted) {
        final imageCount = _selectedImages.length;
        sessionProvider.addMarksToSession(session.id, confirmed);
        _saveMarksToDevice(confirmed, session);
        await authProvider.deductCredits(imageCount);
        _showSnack('${confirmed.length} marks saved to ${session.name}');
        setState(() => _selectedImages.clear());
        LoggerService.instance.logExtraction(subject, imageCount, confirmed.length);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Extraction failed: $e');
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }



  Future<void> _saveMarksToDevice(List<StudentMark> marks, ExtractionSession session) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/marks');
      if (!await folder.exists()) await folder.create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitized = session.course.replaceAll(RegExp(r'[^\w\s-]'), '');
      final jsonFile = File('${folder.path}/${sanitized}_$timestamp.json');
      final data = {
        'sessionId': session.id,
        'sessionName': session.name,
        'course': session.course,
        'extractionType': session.extractionType,
        'maxMark': session.maxMark,
        'extractedAt': DateTime.now().toIso8601String(),
        'marks': marks.map((m) => m.toJson()).toList(),
      };
      await jsonFile.writeAsString(jsonEncode(data));
      final excelFile = await _excelService.generateExcelFile(marks, session.course);
      if (await excelFile.exists()) {
        final excelName = excelFile.path.split('/').last;
        await excelFile.copy('${folder.path}/$excelName');
      }
    } catch (_) {}
  }

  String _todaysSession() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  void _showExportChooser(ExtractionSession session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Export Format', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: EduColors.royalBlue),
                title: Text('Excel (.xlsx)', style: GoogleFonts.poppins()),
                subtitle: Text('Formatted spreadsheet', style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportSessionResults(session, 'xlsx');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: EduColors.royalBlue),
                title: Text('CSV (.csv)', style: GoogleFonts.poppins()),
                subtitle: Text('Comma-separated values', style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportSessionResults(session, 'csv');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportSessionResults(ExtractionSession session, String format) async {
    final sp = context.read<SessionProvider>();
    final sessionMarks = sp.getSessionById(session.id)?.marks ?? [];

    if (sessionMarks.isEmpty) {
      _showSnack('No marks to export for ${session.course}');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final subject = session.course;
      if (format == 'csv') {
        final path = await _excelService.generateExport(sessionMarks, subject);
        await share_plus.SharePlus.instance.share(
          share_plus.ShareParams(files: [share_plus.XFile(path)], text: 'Exam marks exported (CSV)'),
        );
      } else {
        await _excelService.shareExport(sessionMarks, subject);
      }
      _showSnack('$subject results exported');
      LoggerService.instance.logExportSuccess(format, subject, sessionMarks.length);
    } catch (e) {
      _showSnack('Export error: $e');
      LoggerService.instance.logExportFailure(format, session.course, e.toString());
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sp, _) {
        final session = sp.activeSession;
        if (session == null) {
          return SafeArea(child: _buildSessionManager(sp));
        }
        return SafeArea(child: _buildWorkspace(session, sp));
      },
    );
  }

  Widget _buildWorkspace(ExtractionSession session, SessionProvider sp) {
    if (session.id != _lastVoiceSessionId && _voiceClassList.isNotEmpty) {
      _lastVoiceSessionId = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _voiceClassList = []);
      });
    } else if (session.id != _lastVoiceSessionId) {
      _lastVoiceSessionId = session.id;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionBanner(session, sp),
              const SizedBox(height: 16),
              _buildWorkspaceTabBar(session, sp, auth),
            ],
          );
        },
      ),
    );
  }

  int _workspaceTab = 0;

  Widget _buildWorkspaceTabBar(ExtractionSession session, SessionProvider sp, AuthProvider auth) {
    final tabs = [
      ('Bulk Import', Icons.cloud_upload_outlined),
      ('Live Scan', Icons.camera_alt_outlined),
      ('Voice Entry', Icons.mic),
      ('Results', Icons.table_chart_outlined),
    ];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: EduColors.white,
            border: Border(bottom: BorderSide(color: EduColors.cardBorder.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final label = tabs[i].$1;
              final icon = tabs[i].$2;
              final isActive = _workspaceTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _workspaceTab = i),
                  child: Container(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? EduColors.royalBlue : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22, color: isActive ? EduColors.royalBlue : EduColors.textMedium),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive ? EduColors.royalBlue : EduColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        if (_workspaceTab == 0)
          _buildBulkImportTab(session)
        else if (_workspaceTab == 1)
          _buildLiveScanTab(session, sp)
        else if (_workspaceTab == 2)
          _buildVoiceEntryTab(session)
        else
          _buildRightColumn(session),
      ],
    );
  }

  Widget _buildBulkImportTab(ExtractionSession session) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSectionCard(
            icon: Icons.cloud_upload_outlined,
            title: 'Bulk Import',
            subtitle: 'Upload exam images in bulk for automated marking',
            child: Column(
              children: [
                _buildUploadSection(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedImages.isNotEmpty && !_isProcessing ? () => _processImages(session) : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(
                      _isProcessing
                          ? 'Processing...'
                          : 'Process (${_selectedImages.length})',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EduColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: EduColors.royalBlue.withValues(alpha: 0.4),
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

  Widget _buildLiveScanTab(ExtractionSession session, SessionProvider sp) {
    return SingleChildScrollView(
      child: _buildSectionCard(
        icon: Icons.camera_alt_outlined,
        title: 'Live Scan',
        subtitle: 'Capture marks directly from camera in real time',
        child: LiveScanner(
          isProcessing: _isProcessing,
          maxMark: session.maxMark,
          onProcess: (files) async {
            setState(() => _selectedImages.addAll(files));
            await _processImages(session);
          },
        ),
      ),
    );
  }

  Widget _buildVoiceEntryTab(ExtractionSession session) {
    return SingleChildScrollView(
      child: _buildSectionCard(
        icon: Icons.mic,
        title: 'Voice Entry',
        subtitle: 'Dictate marks by speaking student positions and scores',
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              // Upload class list — opens file picker directly
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickClassListForVoice(),
                  icon: Icon(
                    _voiceClassList.isEmpty ? Icons.upload_file : Icons.checklist,
                    size: 18,
                  ),
                  label: Text(
                    _voiceClassList.isEmpty
                        ? 'Upload Names'
                        : '${_voiceClassList.length} names loaded',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _voiceClassList.isEmpty ? EduColors.royalBlue : Colors.green,
                    side: BorderSide(
                      color: _voiceClassList.isEmpty
                          ? EduColors.royalBlue.withValues(alpha: 0.4)
                          : Colors.green.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (_isParsingVoiceClassList)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              // Inline voice recording UI — only shown when names are loaded
              if (_voiceClassList.isNotEmpty) ...[
                const SizedBox(height: 20),
                // Mic button area
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _voiceIsRecording ? _stopVoiceRecording : _startVoiceRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _voiceIsRecording ? EduColors.error : EduColors.royalBlue,
                            boxShadow: [
                              BoxShadow(
                                color: (_voiceIsRecording ? EduColors.error : EduColors.royalBlue).withValues(alpha: 0.3),
                                blurRadius: _voiceIsRecording ? 20 : 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _voiceIsRecording ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _voiceIsRecording ? 'Listening... Tap to stop' : 'Tap to start voice entry',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _voiceIsRecording ? EduColors.error : EduColors.textMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.extractionType == 'Group Assignment'
                            ? 'Speak like: "Group one 45, kundi la pili hamsini"'
                            : 'Speak like: "Namba moja 45, number two fifty"',
                        style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textLight),
                      ),
                    ],
                  ),
                ),
                // Class list reference
                _buildVoiceClassListSection(),
                // Transcription
                if (_voiceTranscribedText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: EduColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _voiceTranscribedText,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: EduColors.textDark,
                      ),
                    ),
                  ),
                // Processing indicator
                if (_voiceIsProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                // Error
                if (_voiceErrorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: EduColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: EduColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _voiceErrorMsg!,
                            style: GoogleFonts.poppins(fontSize: 12, color: EduColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Results
                if (_voiceBatchResults.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: EduColors.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: EduColors.surface,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            border: Border(bottom: BorderSide(color: EduColors.cardBorder)),
                          ),
                          child: Text(
                            'Results',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight),
                          ),
                        ),
                        ..._voiceBatchResults.map((r) => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: r != _voiceBatchResults.last
                                ? Border(bottom: BorderSide(color: EduColors.cardBorder))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EduColors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${r.position}',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textMedium),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(r.label, style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textDark))),
                              if (r.success)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+${r.mark.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                )
                              else
                                Text(
                                  r.reason ?? 'Invalid',
                                  style: GoogleFonts.poppins(fontSize: 11, color: EduColors.error),
                                ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceClassListSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: EduColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EduColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: EduColors.cardBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, size: 14, color: EduColors.royalBlue),
                const SizedBox(width: 6),
                Text(
                  'Class List (${_voiceClassList.length})',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(6),
              itemCount: _voiceClassList.length,
              itemBuilder: (context, i) {
                final m = _voiceClassList[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: EduColors.royalBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${i + 1}',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: EduColors.royalBlue),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.studentName ?? m.registrationNumber,
                          style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _startVoiceRecording() {
    if (_speech == null || !_speechAvailable) return;
    setState(() {
      _voiceIsRecording = true;
      _voiceTranscribedText = '';
      _voiceErrorMsg = null;
      _voiceBatchResults = [];
    });
    _speech!.listen(
      onResult: (result) {
        setState(() => _voiceTranscribedText = result.recognizedWords);
      },
      localeId: 'sw-TZ',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  void _stopVoiceRecording() {
    if (_speech == null || !_voiceIsRecording) return;
    _speech!.stop();
    setState(() => _voiceIsRecording = false);
    if (_voiceTranscribedText.trim().isNotEmpty) {
      _processVoiceText(_voiceTranscribedText);
    }
  }

  Future<void> _processVoiceText(String text) async {
    setState(() => _voiceIsProcessing = true);
    final sp = context.read<SessionProvider>();
    final session = sp.activeSession;
    if (session == null) { setState(() => _voiceIsProcessing = false); return; }

    try {
      final extracted = ruleBasedVoiceParser(text);
      if (extracted.isEmpty) {
        setState(() => _voiceErrorMsg = "Couldn't recognize any student index and score. Speak like: 'Namba moja sitini', 'number five forty five'.");
        return;
      }
      final results = <VoiceEntryResult>[];
      for (final pair in extracted) {
        final idx = pair.position - 1;
        final classEntry = (idx >= 0 && idx < _voiceClassList.length) ? _voiceClassList[idx] : null;
        if (pair.mark == null || pair.mark! > session.maxMark) {
          results.add(VoiceEntryResult(
            position: pair.position,
            label: classEntry?.studentName ?? 'Position $pair.position',
            mark: pair.mark ?? 0,
            success: false,
            reason: pair.mark == null ? 'Unrecognized mark' : 'Exceeds max of ${session.maxMark}',
            registrationNumber: classEntry?.registrationNumber,
            studentName: classEntry?.studentName,
          ));
        } else {
          results.add(VoiceEntryResult(
            position: pair.position,
            label: classEntry?.studentName ?? 'Position ${pair.position}',
            mark: pair.mark!,
            success: true,
            registrationNumber: classEntry?.registrationNumber,
            studentName: classEntry?.studentName,
          ));
        }
      }
      setState(() => _voiceBatchResults = results);
      if (results.any((r) => !r.success)) {
        setState(() => _voiceErrorMsg = 'Some entries were invalid. Please repeat.');
      }
      final voiceMarks = results
        .where((r) => r.success)
        .map((r) => StudentMark(
          registrationNumber: r.registrationNumber ?? 'POS-${r.position}',
          studentName: r.studentName ?? 'Position #${r.position}',
          mark: r.mark.toStringAsFixed(0),
          subject: session.course,
          extractedAt: DateTime.now(),
          extractionType: session.extractionType,
          maxMark: session.maxMark,
        ))
        .toList();
      if (voiceMarks.isNotEmpty) {
        sp.addMarksToSession(session.id, voiceMarks);
      }
      final updatedMarks = sp.getSessionById(session.id)?.marks ?? [];
      if (updatedMarks.isNotEmpty) {
        _saveMarksToDevice(updatedMarks, session);
        _showSnack('${results.where((r) => r.success).length} marks saved to ${session.name}');
      }
    } catch (e) {
      setState(() => _voiceErrorMsg = 'Error processing voice: $e');
    } finally {
      setState(() => _voiceIsProcessing = false);
    }
  }

  Future<void> _pickClassListForVoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.first.path!);
    setState(() => _isParsingVoiceClassList = true);
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final parsed = await (ext == 'csv' ? _parseCsvClassList(file) : _parseExcelClassList(file));
      setState(() => _voiceClassList = parsed);
      if (parsed.isNotEmpty) {
        _showSnack('${parsed.length} names loaded');
      } else {
        _showSnack('No names found in the file');
      }
    } catch (e) {
      _showSnack('Failed to parse file: $e');
    } finally {
      setState(() => _isParsingVoiceClassList = false);
    }
  }

  Future<List<StudentMark>> _parseExcelClassList(File file) async {
    final bytes = await file.readAsBytes();
    final excel = excel_pkg.Excel.decodeBytes(bytes);
    final entries = <StudentMark>[];
    for (final table in excel.sheets.values) {
      for (final row in table.rows) {
        if (row.isEmpty) continue;
        final cell0 = row[0];
        if (cell0 == null || cell0.value == null) continue;
        final col0 = cell0.value.toString().trim();
        if (col0.isEmpty || _voiceIsHeader(col0)) continue;
        String reg = col0;
        String name = col0;
        if (row.length >= 2) {
          final cell1 = row[1];
          final v = cell1?.value?.toString().trim() ?? '';
          if (v.isNotEmpty && !_voiceIsHeader(v)) {
            name = v;
          }
        }
        entries.add(StudentMark(
          registrationNumber: reg,
          studentName: name,
          mark: 'N/A',
          subject: '',
          extractedAt: DateTime.now(),
          maxMark: 100,
        ));
      }
      if (entries.isNotEmpty) break;
    }
    return entries;
  }

  Future<List<StudentMark>> _parseCsvClassList(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');
    final entries = <StudentMark>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = _voiceSplitCsvLine(trimmed);
      if (parts.isEmpty) continue;
      final col0 = parts[0].trim();
      if (col0.isEmpty || _voiceIsHeader(col0)) continue;
      String reg = col0;
      String name = col0;
      if (parts.length >= 2) {
        final v = parts[1].trim();
        if (v.isNotEmpty && !_voiceIsHeader(v)) {
          name = v;
        }
      }
      entries.add(StudentMark(
        registrationNumber: reg,
        studentName: name,
        mark: 'N/A',
        subject: '',
        extractedAt: DateTime.now(),
        maxMark: 100,
      ));
    }
    return entries;
  }

  bool _voiceIsHeader(String s) {
    final lower = s.toLowerCase().trim();
    return [
      'name', 'student name', 'student', 'names', 'full name',
      'registration number', 'reg no', 'reg. no', 'reg_no',
      'registration', 's/n', 'sn', 'no', 'number', 'namba',
      'jina', 'majina', 'mwanafunzi', 'class list',
      'admission', 'admission no', 'admission number', 'index',
      'index number', 'serial', 'serial number', '#',
    ].contains(lower);
  }


  List<String> _voiceSplitCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }


  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EduColors.royalBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: EduColors.royalBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: EduColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: EduColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSessionBanner(ExtractionSession session, SessionProvider sp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EduColors.royalBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: EduColors.royalBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.document_scanner, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Max mark: ${session.maxMark} · ${session.markCount} records',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditSessionDialog(session, sp),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => sp.selectSession(null),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(ExtractionSession session) {
    return Consumer2<ResultProvider, SessionProvider>(
      builder: (context, rp, sp, _) {
        final marks = sp.getSessionById(session.id)?.marks ?? rp.getResultsForSubject(session.course);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: EduColors.cardBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        marks.isNotEmpty ? 'Records for ${session.name}' : 'Results',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: EduColors.textDark,
                        ),
                      ),
                    ),
                    if (marks.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.file_download_outlined, size: 20, color: EduColors.royalBlue),
                            tooltip: 'Export',
                            onPressed: _isExporting ? null : () => _showExportChooser(session),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.delete_sweep_outlined, size: 20, color: EduColors.error),
                            tooltip: 'Clear all',
                            onPressed: () {
                              sp.deleteSession(session.id);
                              rp.clearResultsForSubject(session.course);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (_isProcessing)
                _buildProcessingOverlay()
              else if (marks.isEmpty)
                _buildEmptyResults()
              else
                _buildMarksTable(marks, session),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionManager(SessionProvider sp) {
    final sessions = sp.sessions;
    final auth = context.watch<AuthProvider>();
    final recentSessions = sessions.take(10).toList();
    final todaySessions = sessions.where((s) => _isToday(s.createdAt)).toList();

    return CustomScrollView(
      slivers: [
        // ── Hero: clean dashboard header ──────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_timeOfDay()}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: EduColors.textLight,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            _capitalize(auth.user?.name ?? 'Teacher'),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: EduColors.textDark,
                              height: 1.2,
                            ),
                          ),

                        ],
                      ),
                    ),
                    // Credits pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EduColors.royalBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: EduColors.royalBlue.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 13, color: EduColors.royalBlue),
                          const SizedBox(width: 4),
                          Text(
                            '${auth.credits}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: EduColors.royalBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Banner card — replaces the feature card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: EduColors.royalBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: EduColors.royalBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.document_scanner, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sessions.isEmpty
                                      ? 'Ready to mark?'
                                      : 'Continue Marking',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  sessions.isEmpty
                                      ? 'Create your first session to get started'
                                      : '${sessions.length} session${sessions.length != 1 ? 's' : ''} · ${sessions.fold(0, (sum, s) => sum + s.markCount)} marks extracted',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreateSessionDialog(sp),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                'New Session',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: EduColors.royalBlue,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                elevation: 0,
                                overlayColor: EduColors.royalBlue.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          if (auth.credits < 1) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showJoinTeamSheet(context),
                                icon: const Icon(
                                    Icons.group_add,
                                    size: 16,
                                    color: Colors.white),
                                label: Text(
                                  'Join Team',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11),
                                  side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  overlayColor: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── "Continue Watching" row — Recent Sessions ──────────────────
        _buildNetflixRow(
          title: 'Recent Sessions',
          seeAllLabel: sessions.isNotEmpty ? 'See all' : null,
          onSeeAll: () => widget.onNavigateToHistory?.call(),
          child: sessions.isEmpty
              ? _buildEmptyRow()
              : SizedBox(
                  height: 152,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    itemCount: recentSessions.length,
                    itemBuilder: (context, i) =>
                        _buildNetflixCard(recentSessions[i], sp),
                  ),
                ),
        ),

        // ── "New Today" row — only shown when there are today's sessions
        if (todaySessions.isNotEmpty)
          _buildNetflixRow(
            title: 'Added Today',
            child: SizedBox(
              height: 152,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: todaySessions.length,
                itemBuilder: (context, i) =>
                    _buildNetflixCard(todaySessions[i], sp),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// Netflix section row: label + optional "See all" + scrollable child
  Widget _buildNetflixRow({
    required String title,
    String? seeAllLabel,
    VoidCallback? onSeeAll,
    required Widget child,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: EduColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  if (seeAllLabel != null)
                    GestureDetector(
                      onTap: onSeeAll,
                      child: Row(
                        children: [
                          Text(
                            seeAllLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: EduColors.royalBlue,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right,
                              size: 16, color: EduColors.royalBlue),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  /// Netflix-style portrait card — white background, blue icon block on top,
  /// title + meta below. Matches teacher-screen card DNA.
  Widget _buildNetflixCard(ExtractionSession s, SessionProvider sp) {
    return GestureDetector(
      onTap: () => sp.selectSession(s.id),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: EduColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EduColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster block — royalBlueLight background, icon centred
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: EduColors.royalBlueLight,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  Icons.description_outlined,
                  size: 32,
                  color: EduColors.royalBlue,
                ),
              ),
            ),
            // Metadata
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: EduColors.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.markCount} marks',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: EduColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        height: 152,
        decoration: BoxDecoration(
          color: EduColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EduColors.cardBorder),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 36, color: EduColors.textLight.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No sessions yet',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: EduColors.textMedium),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap New Session above to begin',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: EduColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  void _showCreateSessionDialog(SessionProvider sp) {
    final nameCtrl = TextEditingController(
      text: 'Session - ${_todaysSession()}',
    );
    final subjectCtrl = TextEditingController();
    final maxMarkCtrl = TextEditingController(text: '100');
    String extractionType = 'Exam';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DialogHeader(
                  icon: Icons.add_circle,
                  title: 'Create New Session',
                  subtitle: 'Start a new marking batch',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Consumer<CourseProvider>(
                    builder: (context, cp, _) {
                      final courses = cp.courseDisplays;
                      return Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return courses;
                          return courses.where((c) =>
                              c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        initialValue: TextEditingValue(text: subjectCtrl.text),
                        onSelected: (v) {
                          subjectCtrl.text = v.trim();
                          nameCtrl.text = '$v - ${_todaysSession()}';
                        },
                        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                          controller.text = subjectCtrl.text;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Subject *',
                              hintText: 'e.g. Mathematics',
                              prefixIcon: Icon(Icons.book, color: EduColors.royalBlue),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              subjectCtrl.text = v;
                              if (v.trim().isNotEmpty) {
                                nameCtrl.text = '${v.trim()} - ${_todaysSession()}';
                              }
                            },
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                subjectCtrl.text = v.trim();
                                nameCtrl.text = '${v.trim()} - ${_todaysSession()}';
                                onSubmitted();
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Extraction Type',
                      prefixIcon: Icon(Icons.category, color: EduColors.royalBlue),
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: extractionType,
                        isExpanded: true,
                        isDense: true,
                        items: const ['Exam', 'Individual Assignment', 'Group Assignment'].map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(
                                t == 'Exam' ? Icons.assignment
                                    : t == 'Individual Assignment' ? Icons.person
                                    : Icons.group,
                                size: 16,
                                color: EduColors.royalBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(t),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => extractionType = v);
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: maxMarkCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max Mark',
                      prefixIcon: Icon(Icons.straighten, color: EduColors.royalBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Session Name',
                      prefixIcon: Icon(Icons.label, color: EduColors.royalBlue),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DialogFooter(actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final subject = subjectCtrl.text.trim();
                      if (subject.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Please enter a subject', style: GoogleFonts.poppins())),
                        );
                        return;
                      }
                      final maxMark = int.tryParse(maxMarkCtrl.text) ?? 100;
                      sp.createSession(
                        name: nameCtrl.text.trim(),
                        course: subject,
                        extractionType: extractionType,
                        maxMark: maxMark,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text('Create', style: GoogleFonts.poppins()),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSessionDialog(ExtractionSession session, SessionProvider sp) {
    final nameCtrl = TextEditingController(text: session.name);
    final maxMarkCtrl = TextEditingController(text: session.maxMark.toString());
    String extractionType = session.extractionType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogHeader(
                icon: Icons.edit_outlined,
                title: 'Edit Session',
                subtitle: session.course.isNotEmpty ? session.course : 'Update session settings',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Session Name',
                    prefixIcon: Icon(Icons.label, color: EduColors.royalBlue),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Extraction Type',
                    prefixIcon: Icon(Icons.category, color: EduColors.royalBlue),
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: extractionType,
                      isExpanded: true,
                      isDense: true,
                      items: const ['Exam', 'Individual Assignment', 'Group Assignment'].map((t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(
                              t == 'Exam' ? Icons.assignment
                                  : t == 'Individual Assignment' ? Icons.person
                                  : Icons.group,
                              size: 16,
                              color: EduColors.royalBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(t),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => extractionType = v);
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: maxMarkCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Max Mark',
                    prefixIcon: Icon(Icons.straighten, color: EduColors.royalBlue),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DialogFooter(actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final maxMark = int.tryParse(maxMarkCtrl.text) ?? session.maxMark;
                    await sp.renameSession(session.id, name);
                    await sp.editSessionMeta(session.id, extractionType: extractionType, maxMark: maxMark);
                    context.read<AuditProvider>().logExtraction('Session updated: $name');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text('Save', style: GoogleFonts.poppins()),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildUploadSection() {
    return Column(
      children: [
        ImageUploader(
          files: _selectedImages,
          onFilesAdded: (newFiles) {
            setState(() => _selectedImages.addAll(newFiles));
          },
          onFileRemoved: (index) {
            setState(() => _selectedImages.removeAt(index));
          },
          onClearAll: _clearImages,
        ),
      ],
    );
  }


  Widget _buildProcessingOverlay() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: EduColors.royalBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing Mark Sheets',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: EduColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing images...',
            style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.table_chart_outlined, size: 64, color: EduColors.textLight.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Extracted data will appear here',
              style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }

  void _editMarkCell(ExtractionSession session, int index, StudentMark mark, String field) {
    final regCtrl = TextEditingController(text: field == 'reg' ? mark.registrationNumber : '');
    final nameCtrl = TextEditingController(text: field == 'name' ? (mark.studentName ?? '') : '');
    final markCtrl = TextEditingController(text: field == 'mark' ? mark.mark : '');
    final sp = context.read<SessionProvider>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EduColors.royalBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined, color: EduColors.royalBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Edit Record', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: regCtrl,
                decoration: InputDecoration(
                  labelText: 'Registration Number',
                  prefixIcon: Icon(Icons.badge, color: EduColors.royalBlue),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Student Name',
                  prefixIcon: Icon(Icons.person, color: EduColors.royalBlue),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: markCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Mark (Max: ${session.maxMark})',
                  prefixIcon: Icon(Icons.score, color: EduColors.royalBlue),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final updated = StudentMark(
                        registrationNumber: regCtrl.text.trim().isNotEmpty ? regCtrl.text.trim() : mark.registrationNumber,
                        studentName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : mark.studentName,
                        mark: markCtrl.text.trim().isNotEmpty ? markCtrl.text.trim() : mark.mark,
                        subject: session.course,
                        extractedAt: mark.extractedAt,
                        extractionType: session.extractionType,
                        maxMark: session.maxMark,
                      );
                      sp.updateMarkInSession(session.id, index, updated);
                      Navigator.pop(ctx);
                    },
                    child: Text('Save', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarksTable(List<StudentMark> marks, ExtractionSession session) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(EduColors.surface),
          columnSpacing: 24,
          columns: [
            DataColumn(
              label: Text('S/N', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight)),
            ),
            DataColumn(
              label: Text('Reg No.', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight)),
            ),
            DataColumn(
              label: Text('Name', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight)),
            ),
            DataColumn(
              numeric: true,
              label: Text('Mark (Max: ${session.maxMark})', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight)),
            ),
            DataColumn(
              label: Text('%', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight)),
            ),
          ],
          rows: List.generate(marks.length, (idx) {
            final m = marks[idx];
            final score = double.tryParse(m.mark);
            final pct = score != null && session.maxMark > 0 ? (score / session.maxMark * 100).toStringAsFixed(0) : '--';
            return DataRow(cells: [
              DataCell(Text('${idx + 1}', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium))),
              DataCell(
                GestureDetector(
                  onTap: () => _editMarkCell(session, idx, m, 'reg'),
                  child: Text(m.registrationNumber, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: EduColors.royalBlue, decoration: TextDecoration.underline)),
                ),
              ),
              DataCell(
                GestureDetector(
                  onTap: () => _editMarkCell(session, idx, m, 'name'),
                  child: Text(m.studentName ?? '', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium, decoration: TextDecoration.underline)),
                ),
              ),
              DataCell(
                GestureDetector(
                  onTap: () => _editMarkCell(session, idx, m, 'mark'),
                  child: Text(m.mark, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: EduColors.royalBlue, decoration: TextDecoration.underline)),
                ),
              ),
              DataCell(Text('$pct%', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium))),
            ]);
          }),
        ),
      ),
    );
  }
  

  void _clearImages() {
    setState(() {
      _selectedImages.clear();
    });
  }

  String _capitalize(String text) {
    return text.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.poppins()), behavior: SnackBarBehavior.floating),
    );
  }

  void _showJoinTeamSheet(BuildContext context) {
    final codeCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool loading = false;
        String? error;
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: EduColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.vpn_key, color: EduColors.royalBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Join a Team',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EduColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter an invitation code to join your colleague\'s team and share their subscription.',
                  style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Invitation Code',
                    prefixIcon: Icon(Icons.vpn_key, color: EduColors.royalBlue),
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim().toUpperCase();
                          if (code.isEmpty) return;
                          setSheetState(() { loading = true; error = null; });
                          final sub = context.read<SubscriptionProvider>();
                          final success = await sub.joinTeamViaCode(code);
                          if (success && mounted) {
                            context.read<AuthProvider>().refreshCredits();
                            Navigator.pop(ctx);
                            _showSnack('Team joined successfully');
                          } else {
                            setSheetState(() { loading = false; error = 'Invalid or expired code'; });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Join Team', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        });
      },
    ).whenComplete(() => codeCtrl.dispose());
  }

}
