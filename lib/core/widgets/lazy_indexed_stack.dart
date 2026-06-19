import 'package:flutter/material.dart';

/// An [IndexedStack] that builds each child only the first time it becomes the
/// active index, then keeps it alive (offstage) afterwards.
///
/// Plain `IndexedStack` builds *all* children eagerly on first layout — which,
/// for a tabbed shell where some tabs fetch data and render charts, means every
/// screen mounts (and fires its network calls) on the very first frame. That
/// caused noticeable jank on first load, especially on mobile web (iOS Safari).
///
/// This widget defers each child until visited: unvisited slots render an empty
/// placeholder, so only the screens the user actually opens do work — while
/// visited screens stay mounted (state preserved) like a normal IndexedStack.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _activated =
      List<bool>.generate(widget.children.length, (i) => i == widget.index);

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index >= 0 && widget.index < _activated.length) {
      _activated[widget.index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _activated[i] ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
