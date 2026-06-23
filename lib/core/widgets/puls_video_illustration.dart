import 'package:flutter/material.dart';
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
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

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
    if (_hasError) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey.withValues(alpha: 0.5)),
        ),
      );
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    Widget player = AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
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

    if (widget.borderRadius > 0) {
      player = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: player,
      );
    }

    return player;
  }
}
