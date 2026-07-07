import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../user_authentication/auth_api.dart';
import '../task_management/task_api.dart';

class SubmitProofPage extends StatefulWidget {
  const SubmitProofPage({
    super.key,
    required this.taskTitle,
    required this.startTimeLabel,
    required this.taskTimeLabel,
    required this.assignedUserName,
    required this.assignedEmployeeId,
    required this.statusLabel,
    required this.statusBackgroundColor,
    required this.statusForegroundColor,
    required this.showReviewerFeedback,
    required this.canSubmit,
    required this.accessToken,
    required this.entryId,
    required this.onBack,
    required this.onSubmitted,
    this.onEditEntry,
    this.onDeleteEntry,
    this.submittedEvidence = const [],
    this.operatorRemarks = '',
    this.reviewerFeedback = '',
  });

  final String taskTitle;
  final String startTimeLabel;
  final String taskTimeLabel;
  final String assignedUserName;
  final String assignedEmployeeId;
  final String statusLabel;
  final Color statusBackgroundColor;
  final Color statusForegroundColor;
  final bool showReviewerFeedback;
  final bool canSubmit;
  final String accessToken;
  final int entryId;
  final VoidCallback onBack;
  final VoidCallback onSubmitted;
  final VoidCallback? onEditEntry;
  final VoidCallback? onDeleteEntry;
  final List<ProofEvidence> submittedEvidence;
  final String operatorRemarks;
  final String reviewerFeedback;

  @override
  State<SubmitProofPage> createState() => _SubmitProofPageState();
}

enum _ProofStatus { submitted, failed }

enum EvidenceMediaType { image, video }

class ProofEvidence {
  const ProofEvidence({
    required this.name,
    required this.bytes,
    required this.mediaType,
    this.path,
  });

  final String name;
  final Uint8List bytes;
  final EvidenceMediaType mediaType;
  final String? path;

  bool get isVideo => mediaType == EvidenceMediaType.video;

  String get contentType {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'avi' => 'video/x-msvideo',
      _ => isVideo ? 'video/mp4' : 'image/jpeg',
    };
  }
}

class _EvidencePickChoice {
  const _EvidencePickChoice({required this.source, required this.mediaType});

  final ImageSource source;
  final EvidenceMediaType mediaType;
}

class _SubmitProofPageState extends State<SubmitProofPage> {
  final TaskApi _taskApi = TaskApi();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _remarksController = TextEditingController();
  final List<ProofEvidence> _evidence = [];
  _ProofStatus? _status;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _chooseEvidenceSource() async {
    final choice = await showModalBottomSheet<_EvidencePickChoice>(
      context: context,
      backgroundColor: const Color(0xFF303030),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EvidenceSourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Picture',
                  onTap: () => Navigator.of(context).pop(
                    const _EvidencePickChoice(
                      source: ImageSource.gallery,
                      mediaType: EvidenceMediaType.image,
                    ),
                  ),
                ),
                _EvidenceSourceTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Take Photo',
                  onTap: () => Navigator.of(context).pop(
                    const _EvidencePickChoice(
                      source: ImageSource.camera,
                      mediaType: EvidenceMediaType.image,
                    ),
                  ),
                ),
                _EvidenceSourceTile(
                  icon: Icons.video_library_rounded,
                  label: 'Upload Video',
                  onTap: () => Navigator.of(context).pop(
                    const _EvidencePickChoice(
                      source: ImageSource.gallery,
                      mediaType: EvidenceMediaType.video,
                    ),
                  ),
                ),
                _EvidenceSourceTile(
                  icon: Icons.videocam_rounded,
                  label: 'Record Video',
                  onTap: () => Navigator.of(context).pop(
                    const _EvidencePickChoice(
                      source: ImageSource.camera,
                      mediaType: EvidenceMediaType.video,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) {
      return;
    }

    try {
      final pickedFile = switch (choice.mediaType) {
        EvidenceMediaType.image => await _imagePicker.pickImage(
          source: choice.source,
          imageQuality: 85,
          maxWidth: 1800,
        ),
        EvidenceMediaType.video => await _imagePicker.pickVideo(
          source: choice.source,
          maxDuration: const Duration(minutes: 3),
        ),
      };
      if (pickedFile == null) {
        return;
      }
      if (choice.mediaType == EvidenceMediaType.video) {
        final canPreview = await _canPreviewVideo(pickedFile.path);
        if (!mounted) {
          return;
        }
        if (!canPreview) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This video cannot be previewed on this device. Please choose another video.',
              ),
            ),
          );
          return;
        }
      }
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _evidence.add(
          ProofEvidence(
            name: pickedFile.name,
            bytes: bytes,
            mediaType: choice.mediaType,
            path: pickedFile.path,
          ),
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to add evidence.')));
    }
  }

  Future<bool> _canPreviewVideo(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.isInitialized && !controller.value.hasError;
    } catch (_) {
      return false;
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _confirmRemoveEvidence(ProofEvidence evidence) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            primaryColor: CupertinoColors.systemBlue,
          ),
          child: CupertinoAlertDialog(
            title: const Text('Delete evidence?'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Are you sure you want to remove this uploaded evidence?',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldRemove != true || !mounted) {
      return;
    }

    setState(() {
      _evidence.remove(evidence);
    });
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
                      ? _VideoEvidencePlayer(
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

  String _fileSizeLabel(Uint8List bytes) {
    final size = bytes.lengthInBytes;
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  Future<void> _submitProof() async {
    if (_isSubmitting || _evidence.isEmpty || _status == null) {
      return;
    }
    if (_status == _ProofStatus.failed &&
        _remarksController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitter remarks are required when failed.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final message = await _taskApi.submitTaskEntry(
        entryId: widget.entryId,
        accessToken: widget.accessToken,
        status: _status == _ProofStatus.failed ? 'Failed' : 'Submitted',
        submissionRemark: _remarksController.text.trim(),
        evidence: jsonEncode(_evidence.map(_evidencePayload).toList()),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      widget.onSubmitted();
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Map<String, dynamic> _evidencePayload(ProofEvidence evidence) {
    return {
      'filename': evidence.name,
      'content_type': evidence.contentType,
      'media_type': evidence.isVideo ? 'video' : 'image',
      'data': base64Encode(evidence.bytes),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = !widget.canSubmit;
    final isPendingReadOnly =
        isReadOnly && widget.statusLabel.trim().toLowerCase() == 'pending';
    final isExpiredReadOnly =
        isReadOnly && widget.statusLabel.trim().toLowerCase() == 'expired';
    final displayEvidence = isReadOnly ? widget.submittedEvidence : _evidence;
    final hasEvidence = _evidence.isNotEmpty;
    final submitterRemarks = _remarksController.text.trim();
    final requiresRemarks = _status == _ProofStatus.failed;
    final hasRequiredRemarks = !requiresRemarks || submitterRemarks.isNotEmpty;
    final canSubmit =
        widget.canSubmit &&
        hasEvidence &&
        _status != null &&
        hasRequiredRemarks &&
        !_isSubmitting;
    final remarks = widget.operatorRemarks.trim();
    final feedback = widget.reviewerFeedback.trim();

    return Column(
      children: [
        _SubmitProofHeader(
          onBack: widget.onBack,
          title: isExpiredReadOnly ? 'Task Entry' : 'Submit Proof',
          onEditEntry: widget.onEditEntry,
          onDeleteEntry: widget.onDeleteEntry,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
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
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Start ${widget.startTimeLabel}\nDue ${widget.taskTimeLabel}',
                            style: const TextStyle(
                              color: Color(0xFFC7C7C7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TaskStatusChip(
                          label: widget.statusLabel,
                          backgroundColor: widget.statusBackgroundColor,
                          foregroundColor: widget.statusForegroundColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ProofInfoRow(
                      icon: Icons.person_rounded,
                      label: 'Assigned User',
                      value: widget.assignedUserName,
                    ),
                    const SizedBox(height: 8),
                    _ProofInfoRow(
                      icon: Icons.badge_rounded,
                      label: 'Employee ID',
                      value: widget.assignedEmployeeId,
                    ),
                  ],
                ),
              ),
              _ProofSectionTitle(
                title: isReadOnly
                    ? (isPendingReadOnly || isExpiredReadOnly
                          ? 'Evidence'
                          : 'Submitted Evidence')
                    : 'Submit Evidence',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isReadOnly) ...[
                      _UploadDropZone(
                        onTap: _isSubmitting ? null : _chooseEvidenceSource,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final evidence in displayEvidence)
                          _EvidenceThumbnail(
                            evidence: evidence,
                            onTap: () => _viewEvidence(evidence),
                            onRemove: isReadOnly || _isSubmitting
                                ? null
                                : () => _confirmRemoveEvidence(evidence),
                          ),
                        if (!isReadOnly)
                          _AddEvidenceButton(
                            onTap: _isSubmitting ? null : _chooseEvidenceSource,
                          ),
                        if (isReadOnly && displayEvidence.isEmpty)
                          _NoEvidenceView(
                            label: isPendingReadOnly
                                ? 'No evidence submitted yet.'
                                : isExpiredReadOnly
                                ? 'No evidence was submitted before this entry expired.'
                                : 'No evidence submitted.',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isReadOnly) ...[
                const _ProofSectionTitle(title: 'Task Status'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProofStatusButton(
                          label: 'Completed',
                          icon: Icons.check_rounded,
                          selected: _status == _ProofStatus.submitted,
                          selectedColor: const Color(0xFF7CFF8A),
                          selectedTextColor: const Color(0xFF008F13),
                          onPressed: () {
                            if (!_isSubmitting) {
                              setState(() => _status = _ProofStatus.submitted);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _ProofStatusButton(
                          label: 'Failed',
                          icon: Icons.close_rounded,
                          selected: _status == _ProofStatus.failed,
                          selectedColor: const Color(0xFFFFB3B3),
                          selectedTextColor: const Color(0xFFC93535),
                          onPressed: () {
                            if (!_isSubmitting) {
                              setState(() => _status = _ProofStatus.failed);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const _ProofSectionTitle(title: 'Submitter Remarks'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                child: isReadOnly
                    ? _ReadOnlyProofText(
                        text: remarks.isEmpty
                            ? (isPendingReadOnly
                                  ? 'No remarks from submitter yet.'
                                  : isExpiredReadOnly
                                  ? 'No remarks were submitted before this entry expired.'
                                  : 'No remarks from submitter.')
                            : remarks,
                      )
                    : TextField(
                        controller: _remarksController,
                        minLines: 3,
                        maxLines: 5,
                        enabled: !_isSubmitting,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF474747),
                          hintText: 'Add submitter remarks (if any)',
                          errorText: requiresRemarks && !hasRequiredRemarks
                              ? 'Submitter remarks are required when failed.'
                              : null,
                          hintStyle: const TextStyle(
                            color: Color(0xFFC7C7C7),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                          contentPadding: const EdgeInsets.all(18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFC7C7C7),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFC7C7C7),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
              ),
              if (widget.showReviewerFeedback) ...[
                const _ProofSectionTitle(title: 'Reviewer Remarks'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                  child: _ReadOnlyProofText(
                    text: feedback.isEmpty ? 'No feedback.' : feedback,
                  ),
                ),
              ],
              if (!isReadOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: canSubmit ? _submitProof : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF8E8E8E),
                        side: BorderSide(
                          color: canSubmit
                              ? const Color(0xFFC7C7C7)
                              : const Color(0xFF777777),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmitProofHeader extends StatelessWidget {
  const _SubmitProofHeader({
    required this.onBack,
    required this.title,
    this.onEditEntry,
    this.onDeleteEntry,
  });

  final VoidCallback onBack;
  final String title;
  final VoidCallback? onEditEntry;
  final VoidCallback? onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final showActions = onEditEntry != null || onDeleteEntry != null;
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF474747),
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8), width: 1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 62),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IconButton(
                onPressed: onBack,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                iconSize: 32,
              ),
            ),
          ),
          if (showActions)
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
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
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
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

class _ProofInfoRow extends StatelessWidget {
  const _ProofInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC7C7C7), size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 102,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoEvidenceView extends StatelessWidget {
  const _NoEvidenceView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF3F3F3F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
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

class _ReadOnlyProofText extends StatelessWidget {
  const _ReadOnlyProofText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF474747),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7C7C7), width: 1.2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.25,
        ),
      ),
    );
  }
}

class _ProofSectionTitle extends StatelessWidget {
  const _ProofSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      color: const Color(0xFF303030),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFC7C7C7),
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          width: double.infinity,
          height: 158,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.perm_media_rounded,
                color: Color(0xFFC7C7C7),
                size: 54,
              ),
              SizedBox(height: 12),
              Text(
                'Upload Photo or Video',
                style: TextStyle(
                  color: Color(0xFFC7C7C7),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Max 50MB JPG, PNG, MP4',
                style: TextStyle(
                  color: Color(0xFFC7C7C7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddEvidenceButton extends StatelessWidget {
  const _AddEvidenceButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(radius: 8),
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Icon(Icons.add_rounded, color: Color(0xFFC7C7C7), size: 28),
        ),
      ),
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({
    required this.evidence,
    required this.onTap,
    required this.onRemove,
  });

  final ProofEvidence evidence;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: evidence.isVideo
                      ? Container(
                          width: 50,
                          height: 50,
                          color: const Color(0xFF303030),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFFC7C7C7),
                            size: 30,
                          ),
                        )
                      : Image.memory(
                          evidence.bytes,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          semanticLabel: evidence.name,
                        ),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: const Color(0xFF1F1F1F),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoEvidencePlayer extends StatefulWidget {
  const _VideoEvidencePlayer({
    required this.evidence,
    required this.fileSizeLabel,
  });

  final ProofEvidence evidence;
  final String fileSizeLabel;

  @override
  State<_VideoEvidencePlayer> createState() => _VideoEvidencePlayerState();
}

class _VideoEvidencePlayerState extends State<_VideoEvidencePlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  File? _temporaryVideoFile;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final videoFile = await _videoFile();
    final controller = VideoPlayerController.file(videoFile);
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(true);
    if (mounted) {
      controller.setLooping(true);
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
      '${tempDirectory.path}${Platform.pathSeparator}checkops_${DateTime.now().microsecondsSinceEpoch}_$safeName',
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
      return _VideoEvidenceFallback(
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

        if (snapshot.hasError || !controller.value.isInitialized) {
          return _VideoEvidenceFallback(
            name: widget.evidence.name,
            fileSizeLabel: widget.fileSizeLabel,
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

class _VideoEvidenceFallback extends StatelessWidget {
  const _VideoEvidenceFallback({
    required this.name,
    required this.fileSizeLabel,
  });

  final String name;
  final String fileSizeLabel;

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
          const SizedBox(height: 6),
          Text(
            fileSizeLabel,
            style: const TextStyle(
              color: Color(0xFFC7C7C7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofStatusButton extends StatelessWidget {
  const _ProofStatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color selectedTextColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? selectedTextColor
        : const Color(0xFFC7C7C7);

    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 23),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: selected ? selectedColor : const Color(0xFF303030),
          side: BorderSide(
            color: selected ? selectedTextColor : const Color(0xFF1F1F1F),
            width: 2,
          ),
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

class _EvidenceSourceTile extends StatelessWidget {
  const _EvidenceSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({this.radius = 12});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC7C7C7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 7.0;
      const dashSpace = 7.0;
      while (distance < metric.length) {
        final nextDistance = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, nextDistance.clamp(0, metric.length)),
          paint,
        );
        distance = nextDistance + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}
