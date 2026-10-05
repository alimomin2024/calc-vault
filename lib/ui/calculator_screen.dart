import 'package:flutter/material.dart';
import '../core/calculator.dart';
import '../core/vault.dart';
import 'design.dart';

class CalculatorScreen extends StatefulWidget {
  final Vault vault;
  final Future<void> Function() capture;
  const CalculatorScreen({
    super.key,
    required this.vault,
    required this.capture,
  });
  @override
  State<CalculatorScreen> createState() => _CalculatorState();
}

class _CalculatorState extends State<CalculatorScreen> {
  final calculator = Calculator();
  String expression = '', result = '0';
  bool scientific = false, busy = false, completed = false;
  final history = <String>[];
  Future<void> tap(String key) async {
    if (busy) {
      return;
    }
    if (key == '=') {
      if (expression.isEmpty) {
        return;
      }
      setState(() => busy = true);
      try {
        if (widget.vault.pinCandidate(expression)) {
          final before = widget.vault.failures;
          final opened = await widget.vault.authenticate(expression);
          if (opened) {
            return;
          }
          if (widget.vault.failures > before &&
              widget.vault.failures % 3 == 0 &&
              widget.vault.selfieEnabled) {
            await widget.capture();
          }
        }
        final value = Calculator.format(calculator.evaluate(expression));
        if (mounted) {
          setState(() {
            if (!widget.vault.pinCandidate(expression)) {
              history.insert(0, '$expression = $value');
            }
            if (history.length > 20) {
              history.removeLast();
            }
            result = value;
            completed = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => result = 'Error');
        }
      } finally {
        if (mounted) {
          setState(() => busy = false);
        }
      }
      return;
    }
    setState(() {
      if (key == 'AC') {
        expression = '';
        result = '0';
        completed = false;
        return;
      }
      if (key == '⌫') {
        if (expression.isNotEmpty) {
          expression = expression.substring(0, expression.length - 1);
        }
        completed = false;
        return;
      }
      if (completed) {
        expression = ['+', '−', '×', '÷', '^', '%', '±'].contains(key)
            ? result
            : '';
        completed = false;
      }
      if (expression.length >= 160) {
        return;
      }
      if (['sin', 'cos', 'tan', 'log', 'ln', '√'].contains(key)) {
        expression += '$key(';
      } else if (key == 'x²') {
        expression += '^2';
      } else if (key == '±') {
        if (expression.isEmpty) {
          expression = '−';
        } else {
          expression = expression.startsWith('−(') && expression.endsWith(')')
              ? expression.substring(2, expression.length - 1)
              : '−($expression)';
        }
      } else {
        expression += key;
      }
    });
  }

  void showHistory() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: linen,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: 350,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Calculation history', style: editorial(26)),
          const SizedBox(height: 18),
          if (history.isEmpty)
            const Text(
              'Your calculations will appear here.',
              style: TextStyle(color: muted),
            ),
          ...history.map((h) => ListTile(title: Text(h))),
          TextButton(
            onPressed: () {
              setState(history.clear);
              Navigator.pop(context);
            },
            child: const Text('Clear history'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final keys = [
      'AC',
      '(',
      ')',
      '÷',
      '7',
      '8',
      '9',
      '×',
      '4',
      '5',
      '6',
      '−',
      '1',
      '2',
      '3',
      '+',
      '±',
      '0',
      '.',
      '=',
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined, size: 30),
                          const SizedBox(width: 10),
                          Text('Calculator', style: editorial(24)),
                          const Spacer(),
                          IconButton(
                            tooltip: 'History',
                            onPressed: showHistory,
                            icon: const Icon(Icons.history_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            'A SPACE TO THINK',
                            style: TextStyle(
                              color: muted.withValues(alpha: .8),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          const Tag('ON DEVICE', color: khaki),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 170),
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Text(
                                  calculator.degrees ? 'DEG' : 'RAD',
                                  style: const TextStyle(
                                    color: khaki,
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => tap('⌫'),
                                  tooltip: 'Backspace',
                                  icon: const Icon(
                                    Icons.backspace_outlined,
                                    size: 18,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              reverse: true,
                              child: Text(
                                expression.isEmpty ? '0' : expression,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              child: Text(
                                busy ? '…' : result,
                                style: editorial(52, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => scientific = !scientific),
                            icon: Icon(
                              scientific
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                            ),
                            label: Text(
                              scientific
                                  ? 'Scientific mode'
                                  : 'Scientific functions',
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(
                              () => calculator.degrees = !calculator.degrees,
                            ),
                            child: Text(calculator.degrees ? 'DEG' : 'RAD'),
                          ),
                        ],
                      ),
                      if (scientific)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                      'sin',
                                      'cos',
                                      'tan',
                                      'log',
                                      'ln',
                                      '√',
                                      'x²',
                                      '^',
                                      'π',
                                      'e',
                                      '%',
                                    ]
                                    .map(
                                      (key) => ActionChip(
                                        label: Text(key),
                                        onPressed: () => tap(key),
                                        backgroundColor: const Color(
                                          0xFFF4F1EA,
                                        ),
                                        side: BorderSide.none,
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: keys.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.25,
                            ),
                        itemBuilder: (context, index) {
                          final key = keys[index];
                          final op = ['÷', '×', '−', '+'].contains(key);
                          return Semantics(
                            button: true,
                            label: key,
                            child: Material(
                              color: key == '='
                                  ? ink
                                  : op
                                  ? const Color(0xFFF5EFE3)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: key == '=' ? ink : border,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => tap(key),
                                child: Center(
                                  child: Text(
                                    key,
                                    style: TextStyle(
                                      fontSize: key == 'AC' ? 16 : 25,
                                      fontWeight: FontWeight.w500,
                                      color: key == '='
                                          ? Colors.white
                                          : op
                                          ? khaki
                                          : ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'PRECISION IN THE EVERYDAY',
                          style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
