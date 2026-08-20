import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class BkashBalancePill extends StatefulWidget {
  final double balance;

  const BkashBalancePill({super.key, required this.balance});

  @override
  State<BkashBalancePill> createState() => _BkashBalancePillState();
}

class _BkashBalancePillState extends State<BkashBalancePill> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  Timer? _timer;

  void _toggleBalance() {
    if (_isExpanded) return;

    setState(() {
      _isExpanded = true;
    });

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double pillWidth = 150.0;
    const double circleSize = 28.0;
    
    return GestureDetector(
      onTap: _toggleBalance,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: pillWidth,
        height: 36,
        padding: const EdgeInsets.all(4), // 4px padding all around
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // The sliding text container
            AnimatedAlign(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              alignment: _isExpanded ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: pillWidth - 8 - circleSize, // Takes up the remaining space
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _isExpanded 
                        ? widget.balance.toStringAsFixed(2)
                        : 'Tap for balance',
                    key: ValueKey(_isExpanded),
                    style: TextStyle(
                      color: _isExpanded ? Colors.black : Colors.black87,
                      fontWeight: _isExpanded ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            
            // The sliding icon circle
            AnimatedAlign(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              alignment: _isExpanded ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryCyan, // Changed from pink to match theme
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '৳',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
