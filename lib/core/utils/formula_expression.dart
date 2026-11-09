import 'dart:math' as math;

/// A user formula that failed to parse, with a message meant for the user.
class FormulaException implements Exception {
  final String message;
  const FormulaException(this.message);

  @override
  String toString() => message;
}

typedef _Eval = double Function(Map<String, double> vars);

/// A small, safe arithmetic expression language for user-editable formulas.
///
/// Supports numbers, the variables passed to [parse], `+ - * / ^`, parentheses,
/// `×` / `÷`, and the functions `sin cos tan` (degrees), `sqrt abs round
/// floor ceil`, `min max` (any number of arguments) and `pow(x, y)`.
/// Nothing else can be referenced, so a formula can only compute a number.
class FormulaExpression {
  final String source;
  final _Eval _eval;

  FormulaExpression._(this.source, this._eval);

  /// Parses [source], allowing only [variables]. Throws [FormulaException].
  static FormulaExpression parse(String source, {required Set<String> variables}) {
    final parser = _Parser(source, variables);
    final eval = parser.parse();
    return FormulaExpression._(source, eval);
  }

  /// Evaluates with [vars]; missing variables count as 0. May return NaN or
  /// infinity (e.g. division by zero); callers decide how to treat that.
  double evaluate(Map<String, double> vars) => _eval(vars);
}

enum _T { number, ident, op, lparen, rparen, comma, end }

class _Token {
  final _T type;
  final String text;
  final int pos;
  const _Token(this.type, this.text, this.pos);
}

class _Parser {
  final String src;
  final Set<String> variables;
  late final List<_Token> _tokens;
  int _i = 0;

  _Parser(this.src, this.variables);

  static const _functions = {
    'sin', 'cos', 'tan', 'sqrt', 'abs', 'round', 'floor', 'ceil', 'min', 'max', 'pow',
  };

  _Eval parse() {
    if (src.trim().isEmpty) throw const FormulaException('Formula is empty.');
    _tokens = _tokenize();
    final e = _expr();
    if (_peek.type != _T.end) {
      throw FormulaException('Unexpected "${_peek.text}" at position ${_peek.pos + 1}.');
    }
    return e;
  }

  List<_Token> _tokenize() {
    final out = <_Token>[];
    var i = 0;
    while (i < src.length) {
      final c = src[i];
      if (c.trim().isEmpty) {
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(c)) {
        final start = i;
        while (i < src.length && RegExp(r'[0-9.]').hasMatch(src[i])) {
          i++;
        }
        final text = src.substring(start, i);
        if (double.tryParse(text) == null) {
          throw FormulaException('"$text" is not a valid number.');
        }
        out.add(_Token(_T.number, text, start));
      } else if (RegExp(r'[A-Za-z_]').hasMatch(c)) {
        final start = i;
        while (i < src.length && RegExp(r'[A-Za-z_0-9]').hasMatch(src[i])) {
          i++;
        }
        out.add(_Token(_T.ident, src.substring(start, i).toLowerCase(), start));
      } else if ('+-*/^'.contains(c)) {
        out.add(_Token(_T.op, c, i++));
      } else if (c == '×') {
        out.add(_Token(_T.op, '*', i++));
      } else if (c == '÷') {
        out.add(_Token(_T.op, '/', i++));
      } else if (c == '(') {
        out.add(_Token(_T.lparen, c, i++));
      } else if (c == ')') {
        out.add(_Token(_T.rparen, c, i++));
      } else if (c == ',') {
        out.add(_Token(_T.comma, c, i++));
      } else {
        throw FormulaException('Character "$c" is not allowed.');
      }
    }
    out.add(_Token(_T.end, 'end of formula', src.length));
    return out;
  }

  _Token get _peek => _tokens[_i];
  _Token _next() => _tokens[_i++];

  bool _isOp(String op) => _peek.type == _T.op && _peek.text == op;

  // expr := term (('+' | '-') term)*
  _Eval _expr() {
    var left = _term();
    while (_isOp('+') || _isOp('-')) {
      final op = _next().text;
      final a = left;
      final b = _term();
      left = op == '+' ? (v) => a(v) + b(v) : (v) => a(v) - b(v);
    }
    return left;
  }

  // term := unary (('*' | '/') unary)*
  _Eval _term() {
    var left = _unary();
    while (_isOp('*') || _isOp('/')) {
      final op = _next().text;
      final a = left;
      final b = _unary();
      left = op == '*' ? (v) => a(v) * b(v) : (v) => a(v) / b(v);
    }
    return left;
  }

  // unary := ('-' | '+') unary | power
  _Eval _unary() {
    if (_isOp('-')) {
      _next();
      final a = _unary();
      return (v) => -a(v);
    }
    if (_isOp('+')) {
      _next();
      return _unary();
    }
    return _power();
  }

  // power := primary ('^' unary)?   (right-associative)
  _Eval _power() {
    final base = _primary();
    if (_isOp('^')) {
      _next();
      final exp = _unary();
      return (v) => math.pow(base(v), exp(v)).toDouble();
    }
    return base;
  }

  _Eval _primary() {
    final t = _next();
    switch (t.type) {
      case _T.number:
        final n = double.parse(t.text);
        return (_) => n;
      case _T.lparen:
        final e = _expr();
        _expect(_T.rparen, ')');
        return e;
      case _T.ident:
        if (_peek.type == _T.lparen) return _call(t);
        if (_functions.contains(t.text)) {
          throw FormulaException('${t.text} needs parentheses, e.g. ${t.text}(45).');
        }
        if (!variables.contains(t.text)) {
          final list = (variables.toList()..sort()).join(', ');
          throw FormulaException('Unknown name "${t.text}". You can use: $list.');
        }
        final name = t.text;
        return (v) => v[name] ?? 0.0;
      case _T.end:
        throw const FormulaException('Formula ends too early.');
      default:
        throw FormulaException('Unexpected "${t.text}" at position ${t.pos + 1}.');
    }
  }

  _Eval _call(_Token name) {
    if (!_functions.contains(name.text)) {
      throw FormulaException('Unknown function "${name.text}".');
    }
    _expect(_T.lparen, '(');
    final args = <_Eval>[];
    if (_peek.type != _T.rparen) {
      args.add(_expr());
      while (_peek.type == _T.comma) {
        _next();
        args.add(_expr());
      }
    }
    _expect(_T.rparen, ')');

    void arity(int n) {
      if (args.length != n) {
        throw FormulaException('${name.text} takes $n value${n == 1 ? '' : 's'}.');
      }
    }

    const toRad = math.pi / 180.0;
    switch (name.text) {
      case 'sin':
        arity(1);
        return (v) => math.sin(args[0](v) * toRad);
      case 'cos':
        arity(1);
        return (v) => math.cos(args[0](v) * toRad);
      case 'tan':
        arity(1);
        return (v) => math.tan(args[0](v) * toRad);
      case 'sqrt':
        arity(1);
        return (v) => math.sqrt(args[0](v));
      case 'abs':
        arity(1);
        return (v) => args[0](v).abs();
      case 'round':
        arity(1);
        return (v) => args[0](v).roundToDouble();
      case 'floor':
        arity(1);
        return (v) => args[0](v).floorToDouble();
      case 'ceil':
        arity(1);
        return (v) => args[0](v).ceilToDouble();
      case 'pow':
        arity(2);
        return (v) => math.pow(args[0](v), args[1](v)).toDouble();
      case 'min':
      case 'max':
        if (args.isEmpty) throw FormulaException('${name.text} needs at least one value.');
        final isMin = name.text == 'min';
        return (v) => args
            .map((a) => a(v))
            .reduce((x, y) => isMin ? math.min(x, y) : math.max(x, y));
    }
    throw FormulaException('Unknown function "${name.text}".');
  }

  void _expect(_T type, String text) {
    if (_peek.type != type) {
      final got = _peek.type == _T.end ? 'the end' : '"${_peek.text}"';
      throw FormulaException('Expected "$text" but found $got.');
    }
    _next();
  }
}
