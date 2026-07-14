import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/student_mark.dart';
import '../utils/theme.dart';
import '../utils/voice_parser.dart';
import 'upload_class_list_modal.dart';

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

class VoiceEntryModal extends StatefulWidget {
  final int maxMark;
  final void Function(List<VoiceEntryResult> results) onAddMarks;
  final VoidCallback onClose;
  final List<StudentMark>? existingMarks;
  final String extractionType;

  const VoiceEntryModal({
    super.key,
    required this.maxMark,
    required this.onAddMarks,
    required this.onClose,
    this.existingMarks,
    required this.extractionType,
  });

  @override
  State<VoiceEntryModal> createState() => _VoiceEntryModalState();
}

class _VoiceEntryModalState extends State<VoiceEntryModal> {
  stt.SpeechToText? _speech;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String? _errorMsg;
  List<VoiceEntryResult> _lastBatchResults = [];
  bool _speechAvailable = false;
  List<StudentMark> _classList = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech!.initialize(
      onError: (e) => setState(() => _errorMsg = 'Speech error: ${e.errorMsg}'),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (_isRecording) _stopRecording();
        }
      },
    );
    if (!_speechAvailable && mounted) {
      setState(() => _errorMsg = 'Speech recognition not available on this device');
    }
  }

  void _startRecording() {
    if (_speech == null || !_speechAvailable) return;
    setState(() {
      _isRecording = true;
      _transcribedText = '';
      _errorMsg = null;
      _lastBatchResults = [];
    });
    _speech!.listen(
      onResult: (result) {
        setState(() => _transcribedText = result.recognizedWords);
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

  void _stopRecording() {
    if (_speech == null || !_isRecording) return;
    _speech!.stop();
    setState(() => _isRecording = false);
    if (_transcribedText.trim().isNotEmpty) {
      _processTranscribedText(_transcribedText);
    }
  }

  void _showUploadClassList() {
    showDialog(
      context: context,
      builder: (_) => UploadClassListModal(
        existingClassList: _classList,
        onConfirm: (list) {
          setState(() => _classList = list);
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _processTranscribedText(String text) async {
    setState(() => _isProcessing = true);
    try {
      final extracted = ruleBasedVoiceParser(text);
      if (extracted.isEmpty) {
        setState(() => _errorMsg = "Couldn't recognize any student index and score. Speak like: 'Namba moja sitini', 'number five forty five'.");
        return;
      }
      final results = <VoiceEntryResult>[];
      for (final pair in extracted) {
        final idx = pair.position - 1;
        final classEntry = (idx >= 0 && idx < _classList.length) ? _classList[idx] : null;
        if (pair.mark == null || pair.mark! > widget.maxMark) {
          results.add(VoiceEntryResult(
            position: pair.position,
            label: classEntry?.studentName ?? 'Position $pair.position',
            mark: pair.mark ?? 0,
            success: false,
            reason: pair.mark == null ? 'Unrecognized mark' : 'Exceeds max of ${widget.maxMark}',
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
      setState(() => _lastBatchResults = results);
      if (results.any((r) => !r.success)) {
        setState(() => _errorMsg = 'Some entries were invalid. Please repeat.');
      }
      widget.onAddMarks(results);
    } catch (e) {
      setState(() => _errorMsg = 'Error processing voice: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildClassListSection() {
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
                  'Class List (${_classList.length})',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showUploadClassList,
                  child: Text(
                    'Edit',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: EduColors.royalBlue),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(6),
              itemCount: _classList.length,
              itemBuilder: (context, i) {
                final m = _classList[i];
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

  @override
  void dispose() {
    _speech?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: EduColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EduColors.royalBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mic, color: EduColors.royalBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Voice Grade Entry',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: EduColors.textDark),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: EduColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: EduColors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Upload class list button at top
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showUploadClassList,
                        icon: Icon(
                          _classList.isEmpty ? Icons.upload_file : Icons.checklist,
                          size: 16,
                        ),
                        label: Text(
                          _classList.isEmpty ? 'Upload Class List' : 'Class List (${_classList.length} students)',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EduColors.royalBlue,
                          side: BorderSide(color: EduColors.royalBlue.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Mic button area
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isRecording ? _stopRecording : _startRecording,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecording ? EduColors.error : EduColors.royalBlue,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isRecording ? EduColors.error : EduColors.royalBlue).withValues(alpha: 0.3),
                                    blurRadius: _isRecording ? 20 : 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isRecording ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isRecording ? 'Listening... Tap to stop' : 'Tap to start voice entry',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isRecording ? EduColors.error : EduColors.textMedium,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.extractionType == 'Group Assignment'
                                ? 'Speak like: "Group one 45, kundi la pili hamsini"'
                                : 'Speak like: "Namba moja 45, number two fifty"',
                            style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    // Class list reference
                    if (_classList.isNotEmpty)
                      _buildClassListSection()
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: EduColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: EduColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: EduColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Upload a class list to map names to positions.',
                                style: GoogleFonts.poppins(fontSize: 11, color: EduColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Transcription
                    if (_transcribedText.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: EduColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _transcribedText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: EduColors.textDark,
                          ),
                        ),
                      ),
                    // Processing indicator
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    // Error
                    if (_errorMsg != null)
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
                                _errorMsg!,
                                style: GoogleFonts.poppins(fontSize: 12, color: EduColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Results
                    if (_lastBatchResults.isNotEmpty)
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
                            ..._lastBatchResults.map((r) => Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: r != _lastBatchResults.last
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
