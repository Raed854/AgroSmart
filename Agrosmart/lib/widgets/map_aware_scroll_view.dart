import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Scrollable page that stops scrolling while [locked] is true (e.g. while a
/// finger is on an embedded map) so the map can pan.
///
/// Only the scroll physics react to [locked]: the [children] are built once
/// and are not rebuilt when the lock toggles, and they stay alive when
/// scrolled off-screen (so maps don't reload their tiles).
class MapAwareScrollView extends StatelessWidget {
  const MapAwareScrollView({
    super.key,
    required this.locked,
    required this.children,
    this.padding,
  });

  final ValueListenable<bool> locked;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
      builder: (_, isLocked, content) => SingleChildScrollView(
        physics: isLocked
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: padding,
        child: content,
      ),
    );
  }
}
