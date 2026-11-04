import 'package:flutter/material.dart';
import '../models/recorded_video.dart';
import '../services/take_sharing.dart';

typedef ShareButtonBuilder = Widget Function(
  BuildContext context,
  bool isPreparing,
  VoidCallback? onPressed,
);

/// Wraps any share button: shows "preparing" on the button that was tapped,
/// disables every share button while a share is being prepared, and explains
/// when there is nothing left to share.
class ShareAction extends StatefulWidget {
  final List<RecordedVideo> takes;
  final ShareButtonBuilder builder;
  final TakeSharing? sharing;

  const ShareAction({super.key, required this.takes, required this.builder, this.sharing});

  @override
  State<ShareAction> createState() => _ShareActionState();
}

class _ShareActionState extends State<ShareAction> {
  bool _startedHere = false;

  TakeSharing get _sharing => widget.sharing ?? TakeSharing.instance;

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _startedHere = true);
    final attempt = await _sharing.share(widget.takes);
    if (mounted) setState(() => _startedHere = false);
    if (attempt == ShareAttempt.nothingToShare) {
      messenger.showSnackBar(const SnackBar(content: Text('Those video files are no longer on this device.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _sharing.isPreparing,
      builder: (context, anySharePreparing, _) => widget.builder(
        context,
        anySharePreparing && _startedHere,
        anySharePreparing ? null : _share,
      ),
    );
  }
}

/// Small spinner sized to sit where a 20px icon was.
class SharePreparingIndicator extends StatelessWidget {
  const SharePreparingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2));
  }
}
