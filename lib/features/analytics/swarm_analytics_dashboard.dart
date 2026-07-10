import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/count_up_text.dart';

@immutable
class SwarmAgentMetric {
  const SwarmAgentMetric({
    required this.name,
    required this.color,
    required this.confidence,
    required this.confidenceHistory,
    this.activity24h = 0,
    this.pnlUsdc = 0,
  });

  final String name;
  final Color color;
  final double confidence;
  final List<double> confidenceHistory;
  final int activity24h;
  final double pnlUsdc;
}

@immutable
class SwarmAnalyticsSnapshot {
  const SwarmAnalyticsSnapshot({
    required this.totalValueUsdc,
    required this.events24h,
    required this.agents,
    required this.generatedAt,
  });

  const SwarmAnalyticsSnapshot.empty()
      : totalValueUsdc = 0,
        events24h = 0,
        agents = const [],
        generatedAt = null;

  final double totalValueUsdc;
  final int events24h;
  final List<SwarmAgentMetric> agents;
  final DateTime? generatedAt;

  double get averageConfidence {
    if (agents.isEmpty) return 0;
    return agents.fold<double>(0, (sum, agent) => sum + agent.confidence) /
        agents.length;
  }
}

class SwarmAnalyticsDashboard extends StatefulWidget {
  const SwarmAnalyticsDashboard({
    this.snapshot,
    this.updates,
    this.fetchLiveData = true,
    this.refreshInterval = const Duration(seconds: 15),
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final SwarmAnalyticsSnapshot? snapshot;
  final Stream<SwarmAnalyticsSnapshot>? updates;
  final bool fetchLiveData;
  final Duration refreshInterval;
  final EdgeInsetsGeometry padding;

  @override
  State<SwarmAnalyticsDashboard> createState() =>
      _SwarmAnalyticsDashboardState();
}

class _SwarmAnalyticsDashboardState extends State<SwarmAnalyticsDashboard>
    with TickerProviderStateMixin {
  static const _background = Color(0xFF030405);
  static const _surface = Color(0xFF0B0D11);
  static const _line = Color(0xFF20252D);
  static const _text = Color(0xFFF5F7F6);
  static const _muted = Color(0xFF828A88);
  static const _mint = Color(0xFF31F5B0);
  static const _pink = Color(0xFFFF4FA3);
  static const _palette = <Color>[
    Color(0xFF31F5B0),
    Color(0xFF55A8FF),
    Color(0xFFFF4FA3),
    Color(0xFFFFC857),
    Color(0xFFB58CFF),
  ];

  final http.Client _client = http.Client();
  late final AnimationController _transition;
  late final AnimationController _ambient;
  StreamSubscription<SwarmAnalyticsSnapshot>? _subscription;
  Timer? _refreshTimer;
  SwarmAnalyticsSnapshot _from = const SwarmAnalyticsSnapshot.empty();
  SwarmAnalyticsSnapshot _target = const SwarmAnalyticsSnapshot.empty();
  bool _loading = true;
  bool _loadFailed = false;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..value = 1;
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.snapshot != null) {
      _target = widget.snapshot!;
      _loading = false;
    }
    _bindUpdates();
    if (widget.fetchLiveData) {
      _loadLive();
      _refreshTimer =
          Timer.periodic(widget.refreshInterval, (_) => _loadLive());
    } else if (widget.snapshot == null && widget.updates == null) {
      _loading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = context.reduceMotion;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _ambient
        ..stop()
        ..value = 0.5;
      _transition.value = 1;
    } else {
      _ambient.repeat();
    }
  }

  @override
  void didUpdateWidget(SwarmAnalyticsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot && widget.snapshot != null) {
      _applySnapshot(widget.snapshot!);
    }
    if (oldWidget.updates != widget.updates) {
      _bindUpdates();
    }
    if (oldWidget.fetchLiveData != widget.fetchLiveData ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _refreshTimer?.cancel();
      if (widget.fetchLiveData) {
        _loadLive();
        _refreshTimer =
            Timer.periodic(widget.refreshInterval, (_) => _loadLive());
      }
    }
  }

  void _bindUpdates() {
    _subscription?.cancel();
    _subscription = widget.updates?.listen(_applySnapshot);
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$backendUrl$path'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'items': decoded};
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLive() async {
    final responses = await Future.wait([
      _getJson('/api/agents/roster'),
      _getJson('/api/agents/feed?limit=240'),
    ]);
    if (!mounted) return;

    final roster = responses[0];
    final feed = responses[1];
    if (roster == null) {
      setState(() {
        _loading = false;
        _loadFailed = _target.agents.isEmpty;
      });
      return;
    }

    final rawAgents = ((roster['agents'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .take(5)
        .toList();
    if (rawAgents.isEmpty) {
      setState(() {
        _loading = false;
        _loadFailed = _target.agents.isEmpty;
      });
      return;
    }

    final rawEvents =
        ((feed?['events'] as List?) ?? (feed?['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final histories = <String, List<double>>{};
    final activity = <String, int>{};
    var events24h = 0;

    for (final event in rawEvents.reversed) {
      final name = _agentName(event).toLowerCase();
      final timestamp =
          DateTime.tryParse('${event['at'] ?? event['timestamp'] ?? ''}')
              ?.toLocal();
      if (timestamp != null && timestamp.isAfter(cutoff)) {
        events24h++;
        activity[name] = (activity[name] ?? 0) + 1;
      }
      final confidence = _readProbability(event);
      if (confidence != null && name.isNotEmpty) {
        (histories[name] ??= <double>[]).add(confidence);
      }
    }

    var totalValue = 0.0;
    final agents = <SwarmAgentMetric>[];
    for (var index = 0; index < rawAgents.length; index++) {
      final raw = rawAgents[index];
      final name = _agentName(raw, fallback: 'Agent ${index + 1}');
      final key = name.toLowerCase();
      final balance = _readNumber(raw, const [
        'balance',
        'balanceUsdc',
        'tvl',
        'stake',
      ]);
      totalValue += balance ?? 0;
      final confidence = _readProbability(raw) ?? 0.5;
      final previous = _target.agents
          .where((agent) => agent.name.toLowerCase() == key)
          .firstOrNull;
      final history = histories[key] ?? <double>[];
      final resolvedHistory = history.isNotEmpty
          ? history
          : <double>[
              ...?previous?.confidenceHistory
                  .skip(math.max(0, previous.confidenceHistory.length - 19)),
              confidence,
            ];

      agents.add(
        SwarmAgentMetric(
          name: name,
          color: _palette[index % _palette.length],
          confidence: confidence,
          confidenceHistory: _normalizeHistory(resolvedHistory, confidence, 20),
          activity24h: activity[key] ?? 0,
          pnlUsdc: _readNumber(raw, const [
                'pnlUsdc',
                'pnl',
                'profit',
                'netPnl',
              ]) ??
              0,
        ),
      );
    }

    _applySnapshot(
      SwarmAnalyticsSnapshot(
        totalValueUsdc: totalValue,
        events24h: events24h,
        agents: agents,
        generatedAt: DateTime.now(),
      ),
    );
  }

  void _applySnapshot(SwarmAnalyticsSnapshot next) {
    if (!mounted) return;
    final current = _interpolateSnapshot(_from, _target, _transition.value);
    setState(() {
      _from = current;
      _target = next;
      _loading = false;
      _loadFailed = false;
    });
    if (context.reduceMotion) {
      _transition.value = 1;
    } else {
      _transition.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subscription?.cancel();
    _client.close();
    _transition.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _line),
        ),
        child: _loading
            ? const SizedBox(
                height: 320,
                child: Center(
                  child: CircularProgressIndicator(
                    color: _mint,
                    strokeWidth: 2,
                  ),
                ),
              )
            : _loadFailed
                ? _errorState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 540;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(compact),
                          const SizedBox(height: 18),
                          _metrics(compact),
                          const SizedBox(height: 16),
                          Container(
                            height: compact ? 310 : 360,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _line),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _ConfidencePainter(
                                    from: _from,
                                    to: _target,
                                    transition: _transition,
                                    ambient: _ambient,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _legend(),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _header(bool compact) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SWARM ANALYTICS',
          style: TextStyle(
            color: _text,
            fontFamily: PulsColors.fontSans,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_target.agents.length} agents · confidence telemetry',
          style: const TextStyle(
            color: _muted,
            fontFamily: PulsColors.fontSans,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final live = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _mint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _mint.withValues(alpha: 0.34)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 7),
          Text(
            'LIVE',
            style: TextStyle(
              color: _mint,
              fontFamily: PulsColors.fontSans,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const SizedBox(width: 10),
          live,
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.hub_rounded, color: _background, size: 23),
        ),
        const SizedBox(width: 13),
        Expanded(child: title),
        live,
      ],
    );
  }

  Widget _metrics(bool compact) {
    final cards = [
      _MetricTile(
        label: 'SWARM TVL',
        value: _target.totalValueUsdc,
        prefix: '\$',
        suffix: ' USDC',
        decimals: 2,
        accent: _mint,
      ),
      _MetricTile(
        label: 'CONFIDENCE',
        value: _target.averageConfidence * 100,
        suffix: '%',
        decimals: 1,
        accent: _pink,
      ),
      _MetricTile(
        label: 'ACTIVITY · 24H',
        value: _target.events24h.toDouble(),
        decimals: 0,
        accent: const Color(0xFF55A8FF),
      ),
    ];
    if (!compact) {
      return Row(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(child: cards[index]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: cards[2]),
      ],
    );
  }

  Widget _legend() {
    if (_target.agents.isEmpty) {
      return const Text(
        'Waiting for agent confidence signals.',
        style: TextStyle(color: _muted, fontSize: 12),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 500
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final agent in _target.agents)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 24,
                        decoration: BoxDecoration(
                          color: agent.color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _text,
                                fontFamily: PulsColors.fontSans,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${agent.activity24h} signals',
                              style: const TextStyle(
                                color: _muted,
                                fontFamily: PulsColors.fontSans,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CountUpText(
                        agent.confidence * 100,
                        duration: context.motionDuration(
                          const Duration(milliseconds: 720),
                        ),
                        builder: (context, value) => Text(
                          '${value.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: agent.color,
                            fontFamily: PulsColors.fontSans,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFeatures: PulsColors.tabularFigures,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _errorState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_off_rounded, color: _muted, size: 28),
            const SizedBox(height: 12),
            const Text(
              'Swarm telemetry is temporarily unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontFamily: PulsColors.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadLive,
              style: TextButton.styleFrom(foregroundColor: _mint),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
  });

  final String label;
  final double value;
  final Color accent;
  final String prefix;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SwarmAnalyticsDashboardState._surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _SwarmAnalyticsDashboardState._line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _SwarmAnalyticsDashboardState._muted,
              fontFamily: PulsColors.fontSans,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          CountUpText(
            value,
            duration: context.motionDuration(const Duration(milliseconds: 820)),
            builder: (context, animatedValue) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$prefix${animatedValue.toStringAsFixed(decimals)}$suffix',
                maxLines: 1,
                style: TextStyle(
                  color: accent,
                  fontFamily: PulsColors.fontSans,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  fontFeatures: PulsColors.tabularFigures,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidencePainter extends CustomPainter {
  _ConfidencePainter({
    required this.from,
    required this.to,
    required this.transition,
    required this.ambient,
  }) : super(repaint: Listenable.merge([transition, ambient]));

  final SwarmAnalyticsSnapshot from;
  final SwarmAnalyticsSnapshot to;
  final Animation<double> transition;
  final Animation<double> ambient;
  late final TextPainter _labelPainter = TextPainter(
    text: const TextSpan(
      text: 'CONFIDENCE LEVEL · LIVE',
      style: TextStyle(
        color: _muted,
        fontFamily: PulsColors.fontSans,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static const _grid = Color(0xFF242A32);
  static const _muted = Color(0xFF7F8886);

  @override
  void paint(Canvas canvas, Size size) {
    if (to.agents.isEmpty) return;
    final t = Curves.easeInOutCubic.transform(transition.value);
    final chart = Rect.fromLTRB(18, 18, size.width - 18, size.height - 88);
    final barTop = size.height - 62;
    final barBottom = size.height - 20;

    _drawGrid(canvas, chart);

    for (var index = 0; index < to.agents.length; index++) {
      final agent = to.agents[index];
      final oldAgent = _findAgent(from.agents, agent.name) ?? agent;
      final oldSeries = _normalizeHistory(
        oldAgent.confidenceHistory,
        oldAgent.confidence,
        20,
      );
      final newSeries = _normalizeHistory(
        agent.confidenceHistory,
        agent.confidence,
        20,
      );
      final points = <Offset>[];
      for (var point = 0; point < newSeries.length; point++) {
        final value = _lerp(oldSeries[point], newSeries[point], t);
        points.add(
          Offset(
            chart.left + chart.width * point / (newSeries.length - 1),
            chart.bottom - chart.height * value,
          ),
        );
      }

      if (index == 0) {
        final area = _smoothPath(points)
          ..lineTo(chart.right, chart.bottom)
          ..lineTo(chart.left, chart.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                agent.color.withValues(alpha: 0.2),
                agent.color.withValues(alpha: 0),
              ],
            ).createShader(chart),
        );
      }

      canvas.drawPath(
        _smoothPath(points),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 2.8 : 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = agent.color.withValues(alpha: index == 0 ? 1 : 0.74),
      );

      final last = points.last;
      canvas.drawCircle(
        last,
        3.5 + ambient.value * 1.5,
        Paint()..color = agent.color.withValues(alpha: 0.24),
      );
      canvas.drawCircle(last, 2.5, Paint()..color = agent.color);

      final oldConfidence = oldAgent.confidence;
      final confidence = _lerp(oldConfidence, agent.confidence, t);
      final slotWidth = chart.width / to.agents.length;
      final barWidth = math.min(34.0, slotWidth * 0.48);
      final left = chart.left + slotWidth * index + (slotWidth - barWidth) / 2;
      final height = (barBottom - barTop) * confidence;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, barBottom - height, barWidth, height),
        const Radius.circular(7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, barTop, barWidth, barBottom - barTop),
          const Radius.circular(7),
        ),
        Paint()..color = _grid.withValues(alpha: 0.72),
      );
      canvas.drawRRect(rect, Paint()..color = agent.color);
    }

    _labelPainter.paint(canvas, Offset(chart.left, chart.top + 4));
  }

  void _drawGrid(Canvas canvas, Rect chart) {
    final paint = Paint()
      ..color = _grid.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var row = 0; row <= 4; row++) {
      final y = chart.top + chart.height * row / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), paint);
    }
    final nowPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chart.right, chart.top),
      Offset(chart.right, chart.bottom),
      nowPaint,
    );
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _ConfidencePainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.transition != transition ||
        oldDelegate.ambient != ambient;
  }
}

SwarmAnalyticsSnapshot _interpolateSnapshot(
  SwarmAnalyticsSnapshot from,
  SwarmAnalyticsSnapshot to,
  double progress,
) {
  if (to.agents.isEmpty) return to;
  final t = Curves.easeInOutCubic.transform(progress);
  return SwarmAnalyticsSnapshot(
    totalValueUsdc: _lerp(from.totalValueUsdc, to.totalValueUsdc, t),
    events24h:
        _lerp(from.events24h.toDouble(), to.events24h.toDouble(), t).round(),
    generatedAt: to.generatedAt,
    agents: [
      for (final agent in to.agents)
        () {
          final old = _findAgent(from.agents, agent.name) ?? agent;
          final oldHistory =
              _normalizeHistory(old.confidenceHistory, old.confidence, 20);
          final newHistory =
              _normalizeHistory(agent.confidenceHistory, agent.confidence, 20);
          return SwarmAgentMetric(
            name: agent.name,
            color: agent.color,
            confidence: _lerp(old.confidence, agent.confidence, t),
            confidenceHistory: [
              for (var index = 0; index < newHistory.length; index++)
                _lerp(oldHistory[index], newHistory[index], t),
            ],
            activity24h: _lerp(
              old.activity24h.toDouble(),
              agent.activity24h.toDouble(),
              t,
            ).round(),
            pnlUsdc: _lerp(old.pnlUsdc, agent.pnlUsdc, t),
          );
        }(),
    ],
  );
}

SwarmAgentMetric? _findAgent(List<SwarmAgentMetric> agents, String name) {
  for (final agent in agents) {
    if (agent.name.toLowerCase() == name.toLowerCase()) return agent;
  }
  return null;
}

List<double> _normalizeHistory(
  List<double> values,
  double fallback,
  int length,
) {
  if (values.isEmpty) return List<double>.filled(length, fallback);
  final normalized = values
      .map((value) => value.clamp(0.0, 1.0).toDouble())
      .toList(growable: false);
  if (normalized.length == length) return normalized;
  if (normalized.length > length) {
    return normalized.sublist(normalized.length - length);
  }
  return <double>[
    ...List<double>.filled(length - normalized.length, normalized.first),
    ...normalized,
  ];
}

String _agentName(Map<String, dynamic> value, {String fallback = ''}) {
  return '${value['name'] ?? value['agentName'] ?? value['agent'] ?? value['key'] ?? fallback}'
      .trim();
}

double? _readNumber(Map<String, dynamic> value, List<String> keys) {
  for (final key in keys) {
    final raw = value[key];
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse('$raw');
    if (parsed != null) return parsed;
  }
  return null;
}

double? _readProbability(Map<String, dynamic> value) {
  final raw = _readNumber(value, const [
    'confidence',
    'conviction',
    'probability',
    'winRate',
    'accuracy',
    'score',
  ]);
  if (raw == null) return null;
  final normalized = raw > 1 ? raw / 100 : raw;
  return normalized.clamp(0.0, 1.0).toDouble();
}

double _lerp(double start, double end, double t) => start + (end - start) * t;
