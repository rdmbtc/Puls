import 'dart:math' as math;
import 'dart:typed_data';

abstract final class FastTrig {
  static const int _size = 4096;
  static const int _mask = _size - 1;
  static const double _radiansToIndex = _size / (math.pi * 2);
  static final Float64List _sin = Float64List.fromList(
    List<double>.generate(
      _size,
      (index) => math.sin(index * math.pi * 2 / _size),
      growable: false,
    ),
  );

  static double sinRadians(double radians) =>
      _sin[(radians * _radiansToIndex).round() & _mask];

  static double cosRadians(double radians) =>
      _sin[((radians * _radiansToIndex).round() + _size ~/ 4) & _mask];

  static double sinTurns(double turns) => _sin[(turns * _size).round() & _mask];

  static double cosTurns(double turns) =>
      _sin[((turns * _size).round() + _size ~/ 4) & _mask];
}
