import 'package:flutter/material.dart';
import 'dart:ui';

enum SideOverlayDirection { left, right }

Future<T?> showSideOverlaySheet<T>({
  required BuildContext context,
  required SideOverlayDirection direction,
  required WidgetBuilder builder,
  double widthFactor = 0.5,
  double maxWidth = 520,
  Color barrierColor = const Color(0x66000000),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierDismissible: true,
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth =
                (constraints.maxWidth * widthFactor).clamp(280.0, maxWidth).toDouble();
            final panelHeight = (constraints.maxHeight * 0.86).clamp(320.0, constraints.maxHeight - 24).toDouble();

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Align(
                  alignment: direction == SideOverlayDirection.left
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 20,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: SizedBox(
                      width: panelWidth,
                      height: panelHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: builder(dialogContext),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final beginOffset = direction == SideOverlayDirection.left
          ? const Offset(-1, 0)
          : const Offset(1, 0);

      return SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}
