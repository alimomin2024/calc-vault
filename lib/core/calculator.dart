import 'dart:math' as math;

/// Recursive descent parser. No eval, network, or executable input.
class Calculator {
  String _input = '';
  int _position = 0;
  bool degrees = true;

  double evaluate(String expression) {
    _input = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('π', 'pi')
        .replaceAll('√', 'sqrt');
    _position = 0;
    final value = _sum();
    _space();
    if (_position != _input.length || !value.isFinite) {
      throw const FormatException('Invalid calculation');
    }
    return value;
  }

  void _space() {
    while (_position < _input.length && _input[_position] == ' ') {
      _position++;
    }
  }

  bool _take(String token) {
    _space();
    if (_input.startsWith(token, _position)) {
      _position += token.length;
      return true;
    }
    return false;
  }

  double _sum() {
    var n = _product();
    while (true) {
      if (_take('+')) {
        n += _product();
      } else if (_take('-')) {
        n -= _product();
      } else {
        return n;
      }
    }
  }

  double _product() {
    var n = _unary();
    while (true) {
      if (_take('*')) {
        n *= _unary();
      } else if (_take('/')) {
        n /= _unary();
      } else {
        return n;
      }
    }
  }

  double _unary() {
    if (_take('+')) {
      return _unary();
    }
    if (_take('-')) {
      return -_unary();
    }
    return _power();
  }

  double _power() {
    var n = _atom();
    while (_take('%')) {
      n /= 100;
    }
    if (_take('^')) {
      n = math.pow(n, _unary()).toDouble();
    }
    return n;
  }

  double _atom() {
    if (_take('(')) {
      final n = _sum();
      if (!_take(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return n;
    }
    if (_take('pi')) {
      return math.pi;
    }
    if (_take('e')) {
      return math.e;
    }
    for (final name in ['sqrt', 'sin', 'cos', 'tan', 'log', 'ln', 'abs']) {
      if (_take(name)) {
        if (!_take('(')) {
          throw const FormatException('Function requires parentheses');
        }
        final n = _sum();
        if (!_take(')')) {
          throw const FormatException('Missing closing parenthesis');
        }
        final angle = degrees ? n * math.pi / 180 : n;
        return switch (name) {
          'sqrt' => math.sqrt(n),
          'sin' => math.sin(angle),
          'cos' => math.cos(angle),
          'tan' => math.tan(angle),
          'log' => math.log(n) / math.ln10,
          'ln' => math.log(n),
          _ => n.abs(),
        };
      }
    }
    _space();
    final start = _position;
    while (_position < _input.length &&
        RegExp(r'[0-9.]').hasMatch(_input[_position])) {
      _position++;
    }
    if (start == _position) {
      throw const FormatException('Expected a number');
    }
    return double.parse(_input.substring(start, _position));
  }

  static String format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    final parts = value.toStringAsPrecision(12).split('e');
    final mantissa = parts.first.replaceFirst(RegExp(r'\.?0+$'), '');
    return parts.length == 1 ? mantissa : '${mantissa}e${parts.last}';
  }
}
