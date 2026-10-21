/// Small deterministic PRNG (xorshift32). Own implementation so level
/// generation is identical on every platform, including web.
class Rng {
  Rng(int seed) : _s = _init(seed);

  int _s;

  static const int _mask32 = 0xFFFFFFFF;

  /// Xorshift has no zero state; a zero seed starts here (golden ratio).
  static const int _zeroSeed = 0x9E3779B9;

  /// Marsaglia's xorshift32 shift triple.
  static const int _shiftA = 13;
  static const int _shiftB = 17;
  static const int _shiftC = 5;

  /// 2^32, to turn a 32-bit draw into [0, 1).
  static const double _range32 = 4294967296.0;

  static int _init(int seed) {
    final s = seed & _mask32;
    return s == 0 ? _zeroSeed : s;
  }

  int nextU32() {
    var x = _s;
    x ^= (x << _shiftA) & _mask32;
    x ^= x >>> _shiftB;
    x ^= (x << _shiftC) & _mask32;
    _s = x & _mask32;
    return _s;
  }

  /// Uniform in [0, max).
  int nextInt(int max) => nextU32() % max;

  double nextDouble() => nextU32() / _range32;

  bool chance(double p) => nextDouble() < p;

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }
}
