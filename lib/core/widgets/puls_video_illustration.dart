import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';

/// A looping, autoplaying MP4 illustration widget that loads from assets.
/// Designed for decorative use (no audio, no controls).
class PulsVideoIllustration extends StatefulWidget {
  const PulsVideoIllustration({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = 16.0,
    this.fallback,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? fallback;

  @override
  State<PulsVideoIllustration> createState() => _PulsVideoIllustrationState();
}

class _PulsVideoIllustrationState extends State<PulsVideoIllustration> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(PulsVideoIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _disposeController();
      _initController();
    }
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.asset(widget.asset);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0); // Mute
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error initializing video player for asset ${widget.asset}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.dispose();
    }
    _initialized = false;
    _hasError = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showFallback = _hasError || !_initialized || controller == null;

    Widget currentChild;

    if (showFallback) {
      currentChild = widget.fallback ?? SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey.withValues(alpha: 0.5)),
        ),
      );
    } else {
      Widget player = AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: _BlendMask(
          blendMode: BlendMode.screen,
          child: VideoPlayer(controller),
        ),
      );

      if (widget.width != null || widget.height != null) {
        player = SizedBox(
          width: widget.width,
          height: widget.height,
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: player,
          ),
        );
      }
      currentChild = player;
    }

    if (widget.borderRadius > 0) {
      currentChild = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: currentChild,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(showFallback),
        child: currentChild,
      ),
    );
  }
}

class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({
    required this.blendMode,
    super.child,
  });

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(context) {
    return _RenderBlendMask(blendMode);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(BlendMode blendMode) : _blendMode = blendMode;

  BlendMode _blendMode;

  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = _blendMode,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}
