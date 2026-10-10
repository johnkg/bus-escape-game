/// Small deterministic PRNG (xorshift32). Own implementation so level
/// generation is identical on every platform, including web.
class Rng {
  Rng(int seed) : _s = _init(seed);

  int _s;

  static int _init(int seed) {
    final s = seed & 0xFFFFFFFF;
    return s == 0 ? 0x9E3779B9 : s;
  }

  int nextU32() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >>> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  /// Uniform in [0, max).
  int nextInt(int max) => nextU32() % max;

  double nextDouble() => nextU32() / 4294967296.0;

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
