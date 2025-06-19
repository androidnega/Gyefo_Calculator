import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiveTimeWidget extends StatefulWidget {
  final TextStyle? textStyle;
  final TextAlign? textAlign;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const LiveTimeWidget({
    super.key,
    this.textStyle,
    this.textAlign,
    this.backgroundColor,
    this.padding,
  });

  @override
  State<LiveTimeWidget> createState() => _LiveTimeWidgetState();
}

class _LiveTimeWidgetState extends State<LiveTimeWidget> {
  late Timer _timer;
  late String _currentTime;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final formattedTime = DateFormat('HH:mm:ss').format(now);
    
    if (mounted) {
      setState(() {
        _currentTime = formattedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: widget.backgroundColor != null
          ? BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Text(
        _currentTime,
        style: widget.textStyle ??
            Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Theme.of(context).primaryColor,
            ),
        textAlign: widget.textAlign ?? TextAlign.center,
      ),
    );
  }
}
