import 'package:flutter_test/flutter_test.dart';
import 'package:calc_vault/core/calculator.dart';

void main() {
  test('Scientific operations, precedence and display symbols', () {
    final c = Calculator();
    expect(c.evaluate('2+3×4'), 14);
    expect(c.evaluate('(2+3)×4'), 20);
    expect(c.evaluate('√(81)+50%'), 9.5);
    expect(c.evaluate('200×10%'), 20);
    expect(c.evaluate('2^3^2'), 512);
    expect(c.evaluate('−2^2'), -4);
    expect(c.evaluate('sin(30)'), closeTo(.5, 1e-10));
    expect(c.evaluate('log(100)+ln(e)'), closeTo(3, 1e-10));
    c.degrees = false;
    expect(c.evaluate('cos(π)'), closeTo(-1, 1e-10));
  });
  test('Invalid input fails without evaluation', () {
    for (final input in [
      '1÷0',
      '√(−1)',
      '(2+3',
      '2+evil',
      '1..5',
      'sin30',
      '',
    ]) {
      expect(() => Calculator().evaluate(input), throwsFormatException);
    }
  });
  test('Formats small and large results accurately', () {
    expect(Calculator.format(100), '100');
    expect(Calculator.format(0.125), '0.125');
    expect(double.parse(Calculator.format(1e20)), 1e20);
    expect(double.parse(Calculator.format(1e-10)), 1e-10);
  });
}
