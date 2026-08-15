import 'dart:async';
import 'package:flutter/material.dart';

class CountdownTimerWidget extends StatefulWidget {
  final DateTime targetTime;
  final String prefixText;
  final String finishedText;
  final VoidCallback? onFinished;

  const CountdownTimerWidget({
    super.key,
    required this.targetTime,
    this.prefixText = 'Starts in: ',
    this.finishedText = 'LIVE NOW',
    this.onFinished,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (widget.targetTime.isAfter(now)) {
      if (mounted) {
        setState(() {
          _timeLeft = widget.targetTime.difference(now);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = Duration.zero;
        });
      }
      _timer?.cancel();
      if (widget.onFinished != null) widget.onFinished!();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) {
      return Text(
        widget.finishedText,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
      );
    }

    return Text(
      '${widget.prefixText}${_formatDuration(_timeLeft)}',
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
    );
  }
}
