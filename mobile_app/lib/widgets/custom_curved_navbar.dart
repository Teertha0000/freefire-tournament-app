import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class CustomCurvedNavBar extends StatefulWidget {
  final List<IconData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color backgroundColor;
  final Color activeColor;
  final Color inactiveColor;

  const CustomCurvedNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.backgroundColor,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  State<CustomCurvedNavBar> createState() => _CustomCurvedNavBarState();
}

class _CustomCurvedNavBarState extends State<CustomCurvedNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  
  double _previousPosition = 0.0;
  double _currentPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _anim.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(CustomCurvedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousPosition = _currentPosition;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Calculate the x-coordinate for a given index.
  // We use fixed horizontal padding to push the first and last icons inward
  // so their cutouts never collide with the rounded corners!
  double _getIconX(int index, double width) {
    if (widget.items.isEmpty) return 0;
    
    // We must ensure the horizontal padding is large enough that the cutout 
    // never hits the massive 35px rounded corners.
    // cornerRadius (35) + dx (47.906) = 82.906
    const double horizontalPadding = 83.0; 
    
    if (widget.items.length == 1) return width / 2;
    
    double spacing = (width - (horizontalPadding * 2)) / (widget.items.length - 1);
    return horizontalPadding + (index * spacing);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        
        double targetPosition = _getIconX(widget.selectedIndex, width);
        if (_controller.value == 0 && _previousPosition == 0.0) {
          _previousPosition = targetPosition;
        }
        
        _currentPosition = lerpDouble(_previousPosition, targetPosition, _anim.value) ?? targetPosition;

        return SizedBox(
          height: 100, // Total height including the overflow of the floating circle
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The main glassmorphic background with the cutout
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 70, // Actual navbar height
                child: CustomPaint(
                  painter: _NavBarPainter(
                    cutoutX: _currentPosition,
                    backgroundColor: widget.backgroundColor,
                  ),
                ),
              ),
              
              // Inactive Icons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 70,
                child: Stack( // <--- CHANGED FROM Row to Stack
                  children: List.generate(widget.items.length, (index) {
                    final double iconX = _getIconX(index, width);
                    // Determine how close the cutout is to this icon to fade it out/slide it down
                    double distance = (_currentPosition - iconX).abs();
                    double opacity = 1.0;
                    double offsetY = 0.0;
                    if (distance < 50) {
                      double factor = (50 - distance) / 50; // 1 when exact match, 0 when far
                      opacity = 1.0 - factor;
                      offsetY = factor * 40; // push down as cutout goes over it
                    }
                    
                    return PositionedIcon(
                      x: iconX,
                      y: 35 + offsetY, // center of 70 height + push down
                      opacity: opacity,
                      child: GestureDetector(
                        onTap: () => widget.onTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          child: Icon(
                            widget.items[index],
                            color: widget.inactiveColor,
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              // The Floating Active Circle
              Positioned(
                bottom: 27, // Mathematically aligns the circle center exactly to Y_c = 15
                left: _currentPosition - 28, // 28 is circle radius (56 diameter)
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.activeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.activeColor.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.items[widget.selectedIndex],
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PositionedIcon extends StatelessWidget {
  final double x;
  final double y;
  final double opacity;
  final Widget child;

  const PositionedIcon({
    super.key,
    required this.x,
    required this.y,
    required this.opacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 25, // half of width 50
      bottom: 70 - y - 25, // Convert y from top to bottom
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: child,
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  final double cutoutX;
  final Color backgroundColor;

  _NavBarPainter({required this.cutoutX, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    const double cornerRadius = 35.0; // Beautiful, massive corner radius
    
    // Mathematical exact geometry for a perfectly uniform 8px gap
    final double X = cutoutX;
    const double R_f = 12.0; // Fillet arc radius
    const double R_m = 36.0; // Main arc radius (28 circle + 8 gap)
    const double dx = 47.906; // Exact tangent distance calculated
    
    path.moveTo(0, size.height);
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    
    // Safety check: if cutout is too far left, don't break the path
    double safeCutoutX = X;
    if (safeCutoutX - dx < cornerRadius) {
      safeCutoutX = cornerRadius + dx;
    }
    if (safeCutoutX + dx > size.width - cornerRadius) {
      safeCutoutX = size.width - cornerRadius - dx;
    }

    path.lineTo(safeCutoutX - dx, 0);
    
    // Left Fillet Arc (Rounds down smoothly from the flat top)
    path.arcToPoint(
      Offset(safeCutoutX - 35.93, 12.75),
      radius: const Radius.circular(R_f),
      clockwise: true,
    );
    
    // Main Cutout Arc (Perfectly traces the 56px circle with an 8px uniform gap)
    path.arcToPoint(
      Offset(safeCutoutX + 35.93, 12.75),
      radius: const Radius.circular(R_m),
      clockwise: false,
      largeArc: true, // Forces the arc to trace the deep bottom instead of the shallow path
    );
    
    // Right Fillet Arc (Rounds back up smoothly to the flat top)
    path.arcToPoint(
      Offset(safeCutoutX + dx, 0),
      radius: const Radius.circular(R_f),
      clockwise: true,
    );
    
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height);
    path.close();

    // Draw shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.5), 20, true);
    
    // Draw background
    canvas.drawPath(path, paint);
    
    // Draw subtle glassmorphic border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter oldDelegate) {
    return oldDelegate.cutoutX != cutoutX || oldDelegate.backgroundColor != backgroundColor;
  }
}
