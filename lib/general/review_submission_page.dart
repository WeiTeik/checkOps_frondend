import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReviewSubmissionPage extends StatefulWidget {
  const ReviewSubmissionPage({
    super.key,
    required this.taskTitle,
    required this.submittedTimeLabel,
    required this.onBack,
    this.operatorName = 'Thien Kian Foh',
    this.operatorEmployeeId = '167384965',
    this.operatorRemarks =
        'All pump operating normally. Water pressure stable at 4.2 bar. No visible leaks or corrosion found.',
    this.qcFeedback = '',
    this.showOperatorDetails = true,
    this.showQcFeedback = true,
    this.showReviewActions = true,
  });

  final String taskTitle;
  final String submittedTimeLabel;
  final VoidCallback onBack;
  final String operatorName;
  final String operatorEmployeeId;
  final String operatorRemarks;
  final String qcFeedback;
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
  int _selectedEvidenceIndex = 1;

  late final List<Uint8List?> _evidence = List<Uint8List?>.filled(4, null);

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
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
        _ReviewSubmissionHeader(onBack: widget.onBack),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        const SizedBox(width: 10),
                        const _SubmittedChip(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted on ${widget.submittedTimeLabel}',
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
                child: SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _evidence.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _EvidencePreviewTile(
                        imageBytes: _evidence[index],
                        isSelected: index == _selectedEvidenceIndex,
                        onTap: () {
                          setState(() => _selectedEvidenceIndex = index);
                        },
                      );
                    },
                  ),
                ),
              ),
              const _ReviewSectionTitle(title: 'Operator remarks'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                child: Text(
                  widget.operatorRemarks,
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
                const _ReviewSectionTitle(title: 'QC feedback (optional)'),
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
                                hintText: 'Add remarks...',
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
  const _ReviewSubmissionHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
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
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _SubmittedChip extends StatelessWidget {
  const _SubmittedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF7CFF8A),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Text(
        'Submitted',
        style: TextStyle(
          color: Color(0xFF008F13),
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
  const _EvidencePreviewTile({
    required this.imageBytes,
    required this.isSelected,
    required this.onTap,
  });

  final Uint8List? imageBytes;
  final bool isSelected;
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
          border: Border.all(
            color: isSelected ? const Color(0xFF23A8FF) : Colors.transparent,
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageBytes == null
            ? null
            : Image.memory(imageBytes!, fit: BoxFit.cover),
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
