import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'submit_proof_page.dart';

class ReviewSubmissionPage extends StatefulWidget {
  const ReviewSubmissionPage({
    super.key,
    required this.taskTitle,
    required this.startTimeLabel,
    required this.dueTimeLabel,
    required this.submittedTimeLabel,
    required this.onBack,
    required this.statusLabel,
    required this.statusBackgroundColor,
    required this.statusForegroundColor,
    this.operatorName = 'Thien Kian Foh',
    this.operatorEmployeeId = '167384965',
    this.operatorRemarks = '',
    this.qcFeedback = '',
    this.submittedEvidence = const [],
    this.onEditEntry,
    this.onDeleteEntry,
    this.showOperatorDetails = true,
    this.showQcFeedback = true,
    this.showReviewActions = true,
  });

  final String taskTitle;
  final String startTimeLabel;
  final String dueTimeLabel;
  final String submittedTimeLabel;
  final VoidCallback onBack;
  final String statusLabel;
  final Color statusBackgroundColor;
  final Color statusForegroundColor;
  final String operatorName;
  final String operatorEmployeeId;
  final String operatorRemarks;
  final String qcFeedback;
  final List<ProofEvidence> submittedEvidence;
  final VoidCallback? onEditEntry;
  final VoidCallback? onDeleteEntry;
  final bool showOperatorDetails;
  final bool showQcFeedback;
  final bool showReviewActions;

  @override
  State<ReviewSubmissionPage> createState() => _ReviewSubmissionPageState();
}

class _ReviewSubmissionPageState extends State<ReviewSubmissionPage> {
  late final TextEditingController _feedbackController = TextEditingController(
    text: widget.qcFeedback,
  );

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _viewEvidence(ProofEvidence evidence) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1F1F1F),
          insetPadding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: evidence.isVideo
                      ? _ReviewVideoEvidence(
                          evidence: evidence,
                          fileSizeLabel: _fileSizeLabel(evidence.bytes),
                        )
                      : InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              evidence.bytes,
                              fit: BoxFit.contain,
                              semanticLabel: evidence.name,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fileSizeLabel(List<int> bytes) {
    final size = bytes.length;
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  void _submitReview(bool accepted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted ? 'Submission accepted.' : 'Submission rejected.',
        ),
      ),
    );
    widget.onBack();
  }

  Future<void> _confirmSubmitReview(bool accepted) async {
    final actionLabel = accepted ? 'Accepted' : 'Rejected';
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            primaryColor: CupertinoColors.systemBlue,
          ),
          child: CupertinoAlertDialog(
            title: Text('$actionLabel submission?'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Are you sure you want to mark this submission as $actionLabel?',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: !accepted,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  actionLabel,
                  style: accepted
                      ? const TextStyle(color: Color(0xFF7CFF8A))
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldSubmit == true) {
      _submitReview(accepted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReviewSubmissionHeader(
          onBack: widget.onBack,
          onEditEntry: widget.onEditEntry,
          onDeleteEntry: widget.onDeleteEntry,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.taskTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Start ${widget.startTimeLabel}\nDue ${widget.dueTimeLabel}\nSubmitted on ${widget.submittedTimeLabel}',
                            style: const TextStyle(
                              color: Color(0xFFC7C7C7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ReviewStatusChip(
                          label: widget.statusLabel,
                          backgroundColor: widget.statusBackgroundColor,
                          foregroundColor: widget.statusForegroundColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.showOperatorDetails) ...[
                const _ReviewSectionTitle(title: 'Operator'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewInfoText('Name: ${widget.operatorName}'),
                      const SizedBox(height: 10),
                      _ReviewInfoText(
                        'Employee ID: ${widget.operatorEmployeeId}',
                      ),
                    ],
                  ),
                ),
              ],
              const _ReviewSectionTitle(title: 'Submitted evidence'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: widget.submittedEvidence.isEmpty
                    ? const _ReviewEmptyState(text: 'No evidence submitted.')
                    : SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.submittedEvidence.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final evidence = widget.submittedEvidence[index];
                            return _EvidencePreviewTile(
                              evidence: evidence,
                              onTap: () => _viewEvidence(evidence),
                            );
                          },
                        ),
                      ),
              ),
              const _ReviewSectionTitle(title: 'Submitter remarks'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                child: Text(
                  widget.operatorRemarks.trim().isEmpty
                      ? 'No remarks from submitter.'
                      : widget.operatorRemarks,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    height: 1.25,
                  ),
                ),
              ),
              if (widget.showQcFeedback) ...[
                _ReviewSectionTitle(
                  title: widget.showReviewActions
                      ? 'Reviewer remarks (optional)'
                      : 'Reviewer remarks',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: widget.showReviewActions
                      ? Column(
                          children: [
                            TextField(
                              controller: _feedbackController,
                              minLines: 3,
                              maxLines: 4,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFD9D9D9),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF23A8FF),
                                    width: 2,
                                  ),
                                ),
                                hintText: 'Add reviewer remarks...',
                                hintStyle: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0,
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: _ReviewDecisionButton(
                                    label: 'Accepted',
                                    icon: Icons.check_rounded,
                                    backgroundColor: const Color(0xFFD9D9D9),
                                    foregroundColor: Colors.black,
                                    borderColor: const Color(0xFFD9D9D9),
                                    onPressed: () => _confirmSubmitReview(true),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _ReviewDecisionButton(
                                    label: 'Rejected',
                                    icon: Icons.close_rounded,
                                    backgroundColor: const Color(0xFFFF4048),
                                    foregroundColor: Colors.black,
                                    borderColor: const Color(0xFFFF4048),
                                    onPressed: () =>
                                        _confirmSubmitReview(false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Text(
                          widget.qcFeedback.trim().isEmpty
                              ? 'No remarks...'
                              : widget.qcFeedback,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            height: 1.25,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewSubmissionHeader extends StatelessWidget {
  const _ReviewSubmissionHeader({
    required this.onBack,
    this.onEditEntry,
    this.onDeleteEntry,
  });

  final VoidCallback onBack;
  final VoidCallback? onEditEntry;
  final VoidCallback? onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final showActions = onEditEntry != null || onDeleteEntry != null;
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF474747),
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            iconSize: 32,
          ),
          Expanded(
            child: Center(
              child: const Text(
                'Review Submission',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          if (showActions)
            PopupMenuButton<String>(
              tooltip: 'Task entry actions',
              color: const Color(0xFF303030),
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              onSelected: (value) {
                if (value == 'edit') {
                  onEditEntry?.call();
                  return;
                }
                onDeleteEntry?.call();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  enabled: onEditEntry != null,
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color: onEditEntry == null
                          ? const Color(0xFF777777)
                          : Colors.white,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: onDeleteEntry != null,
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: onDeleteEntry == null
                          ? const Color(0xFF777777)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ReviewSectionTitle extends StatelessWidget {
  const _ReviewSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      color: const Color(0xFF303030),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFC7C7C7),
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ReviewInfoText extends StatelessWidget {
  const _ReviewInfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
    );
  }
}

class _EvidencePreviewTile extends StatelessWidget {
  const _EvidencePreviewTile({required this.evidence, required this.onTap});

  final ProofEvidence evidence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 96,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF23A8FF), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: evidence.isVideo
            ? const ColoredBox(
                color: Color(0xFF303030),
                child: Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFFC7C7C7),
                    size: 34,
                  ),
                ),
              )
            : Image.memory(
                evidence.bytes,
                fit: BoxFit.cover,
                semanticLabel: evidence.name,
              ),
      ),
    );
  }
}

class _ReviewVideoEvidence extends StatefulWidget {
  const _ReviewVideoEvidence({
    required this.evidence,
    required this.fileSizeLabel,
  });

  final ProofEvidence evidence;
  final String fileSizeLabel;

  @override
  State<_ReviewVideoEvidence> createState() => _ReviewVideoEvidenceState();
}

class _ReviewVideoEvidenceState extends State<_ReviewVideoEvidence> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  File? _temporaryVideoFile;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoFile = await _videoFile();
      final controller = VideoPlayerController.file(videoFile);
      controller.addListener(_syncVideoError);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      _videoError = error.toString();
      rethrow;
    }
  }

  void _syncVideoError() {
    final value = _controller?.value;
    if (value == null || !value.hasError) {
      return;
    }
    if (_videoError == value.errorDescription) {
      return;
    }
    _videoError = value.errorDescription;
    if (mounted) {
      setState(() {});
    }
  }

  Future<File> _videoFile() async {
    final path = widget.evidence.path;
    if (path != null && path.isNotEmpty) {
      return File(path);
    }

    final tempDirectory = Directory.systemTemp;
    final safeName = _videoFileName(
      widget.evidence,
    ).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}checkops_review_${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await file.writeAsBytes(widget.evidence.bytes, flush: true);
    _temporaryVideoFile = file;
    return file;
  }

  String _videoFileName(ProofEvidence evidence) {
    final name = evidence.name.trim().isEmpty ? 'evidence' : evidence.name;
    if (name.contains('.') && !name.endsWith('.')) {
      return name;
    }
    return '$name.mp4';
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncVideoError);
    _controller?.dispose();
    final temporaryVideoFile = _temporaryVideoFile;
    if (temporaryVideoFile != null) {
      temporaryVideoFile.delete().ignore();
    }
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _ReviewVideoFallback(
        name: widget.evidence.name,
        fileSizeLabel: widget.fileSizeLabel,
      );
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 240,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFC7C7C7)),
            ),
          );
        }

        if (_videoError != null ||
            snapshot.hasError ||
            !controller.value.isInitialized) {
          return _ReviewVideoFallback(
            name: widget.evidence.name,
            fileSizeLabel: widget.fileSizeLabel,
            hasDecoderError: true,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _togglePlayback,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF8EDCFF),
                bufferedColor: Color(0xFF777777),
                backgroundColor: Color(0xFF303030),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.evidence.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewVideoFallback extends StatelessWidget {
  const _ReviewVideoFallback({
    required this.name,
    required this.fileSizeLabel,
    this.hasDecoderError = false,
  });

  final String name;
  final String fileSizeLabel;
  final bool hasDecoderError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xFFC7C7C7),
            size: 64,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Video preview unavailable ($fileSizeLabel).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          if (hasDecoderError) ...[
            const SizedBox(height: 8),
            const Text(
              'Android decoder could not open this video.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFC7C7C7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3F3F3F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFC7C7C7),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ReviewDecisionButton extends StatelessWidget {
  const _ReviewDecisionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 23),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
