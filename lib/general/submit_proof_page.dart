import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SubmitProofPage extends StatefulWidget {
  const SubmitProofPage({
    super.key,
    required this.taskTitle,
    required this.taskTimeLabel,
    required this.onBack,
  });

  final String taskTitle;
  final String taskTimeLabel;
  final VoidCallback onBack;

  @override
  State<SubmitProofPage> createState() => _SubmitProofPageState();
}

enum _ProofStatus { completed, failed }

class _ProofEvidence {
  const _ProofEvidence({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _SubmitProofPageState extends State<SubmitProofPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _remarksController = TextEditingController();
  final List<_ProofEvidence> _evidence = [];
  _ProofStatus? _status;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _chooseEvidenceSource() async {
    final source = await showModalBottomSheet<ImageSource>(
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
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                _EvidenceSourceTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Take Photo',
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _evidence.add(_ProofEvidence(name: image.name, bytes: bytes));
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open camera or gallery.')),
      );
    }
  }

  Future<void> _confirmRemoveEvidence(_ProofEvidence evidence) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            primaryColor: CupertinoColors.systemBlue,
          ),
          child: CupertinoAlertDialog(
            title: const Text('Delete picture?'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Are you sure you want to remove this uploaded picture?',
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

  Future<void> _viewEvidence(_ProofEvidence evidence) async {
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
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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

  void _submitProof() {
    if (_evidence.isEmpty || _status == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Proof submitted.')));
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final hasEvidence = _evidence.isNotEmpty;
    final canSubmit = hasEvidence && _status != null;

    return Column(
      children: [
        _SubmitProofHeader(onBack: widget.onBack),
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
                    Text(
                      'Due ${widget.taskTimeLabel}',
                      style: const TextStyle(
                        color: Color(0xFFC7C7C7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const _ProofSectionTitle(title: 'Upload Evidence'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UploadDropZone(onTap: _chooseEvidenceSource),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final evidence in _evidence)
                          _EvidenceThumbnail(
                            evidence: evidence,
                            onTap: () => _viewEvidence(evidence),
                            onRemove: () => _confirmRemoveEvidence(evidence),
                          ),
                        _AddEvidenceButton(onTap: _chooseEvidenceSource),
                      ],
                    ),
                  ],
                ),
              ),
              const _ProofSectionTitle(title: 'Task Status'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProofStatusButton(
                        label: 'Completed',
                        icon: Icons.check_rounded,
                        selected: _status == _ProofStatus.completed,
                        selectedColor: const Color(0xFF7CFF8A),
                        selectedTextColor: const Color(0xFF008F13),
                        onPressed: () {
                          setState(() => _status = _ProofStatus.completed);
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
                          setState(() => _status = _ProofStatus.failed);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const _ProofSectionTitle(title: 'Remarks'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                child: Column(
                  children: [
                    TextField(
                      controller: _remarksController,
                      minLines: 3,
                      maxLines: 5,
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
                        hintText: 'Add remarks (if any)',
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
                    const SizedBox(height: 18),
                    SizedBox(
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
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
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
  const _SubmitProofHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF474747),
        border: Border(bottom: BorderSide(color: Color(0xFFB8B8B8), width: 1)),
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
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Submit Proof',
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
          const _PendingChip(),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD59B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Pending',
        style: TextStyle(
          color: Color(0xFFFF8B2C),
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
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

  final VoidCallback onTap;

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
                Icons.photo_camera_rounded,
                color: Color(0xFFC7C7C7),
                size: 54,
              ),
              SizedBox(height: 12),
              Text(
                'Upload Photo',
                style: TextStyle(
                  color: Color(0xFFC7C7C7),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Max 50MB JPG, PNG',
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

  final VoidCallback onTap;

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

  final _ProofEvidence evidence;
  final VoidCallback onTap;
  final VoidCallback onRemove;

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
                  child: Image.memory(
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
