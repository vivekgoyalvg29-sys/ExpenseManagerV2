import 'package:flutter/material.dart';

class PageContentLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const PageContentLayout({
    super.key,
    required this.child,
    this.maxWidth = 920,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
