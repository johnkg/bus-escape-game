import 'game_state.dart';
import 'refresher.dart';
import 'rng.dart';
import 'level.dart';
import 'rules.dart';

/// Mutable wrapper around immutable [GameState]s: undo history and boosters.
class GameSession {
  GameSession(this.level) : _state = level.toState();

  /// Extra lane slots a player may add per level.
  static const int maxExtraSlots = 3;

  final Level level;
  GameState _state;
  final List<GameState> _history = [];
  int _extraSlots = 0;
  int _blockedTaps = 0;
  int _undos = 0;
  int _hintsUsed = 0;
  int _helpUsed = 0;

  GameState get state => _state;
  bool get canUndo => _history.isNotEmpty;
  int get extraSlots => _extraSlots;

  /// Taps on a bus that could not leave.
  int get blockedTaps => _blockedTaps;
  int get undos => _undos;
  int get hintsUsed => _hintsUsed;

  void noteHintUsed() => _hintsUsed++;

  /// Clear, Sort and Refresh uses.
  int get helpUsed => _helpUsed;

  /// 0 until won. 3 = no mistakes and no help, 2 = help-free but bumped into
  /// a blocked bus, 1 = used undo, an extra slot or a hint.
  int get stars {
    if (_state.status != GameStatus.won) return 0;
    if (_undos > 0 || _extraSlots > 0 || _hintsUsed > 0 || _helpUsed > 0) {
      return helpedStars;
    }
    return _blockedTaps == 0 ? maxStars : cleanStars;
  }

  /// Star ratings, see [stars].
  static const int maxStars = 3;
  static const int cleanStars = 2;
  static const int helpedStars = 1;

  /// Returns true if the bus left the grid.
  bool tap(int busId) {
    final r = Rules.tap(_state, busId);
    if (!r.moved) {
      if (_state.status == GameStatus.playing &&
          _state.busById(busId) != null) {
        _blockedTaps++;
      }
      return false;
    }
    _history.add(_state);
    _state = r.state;
    return true;
  }

  void _commit(GameState next) {
    _history.add(_state);
    _state = next;
    _helpUsed++;
  }

  /// Clear booster: airlift a vehicle into the lane, blocked or not.
  bool clear(int busId) {
    final r = Rules.airlift(_state, busId);
    if (!r.moved) return false;
    _commit(r.state);
    return true;
  }

  /// Sort booster; false if no passenger could be helped.
  bool sort() {
    final next = Rules.sortQueue(_state);
    if (next == null) return false;
    _commit(next);
    return true;
  }

  /// Refresh booster: re-place the vehicles still in the jam.
  bool refresh(Rng rng, {List<int>? fallbackOrder}) {
    final r = Refresher.reshuffle(
      _state,
      rng,
      fallbackOrder: fallbackOrder ?? level.solution,
    );
    if (r == null) return false;
    _commit(r.state);
    return true;
  }

  bool undo() {
    if (_history.isEmpty) return false;
    _undos++;
    var prev = _history.removeLast();
    final total = level.laneSlots + _extraSlots;
    if (prev.lane.length < total) {
      prev = prev.copyWith(
        lane: [
          ...prev.lane,
          ...List<ParkedBus?>.filled(total - prev.lane.length, null),
        ],
      );
    }
    _state = prev.copyWith(status: Rules.evaluate(prev));
    return true;
  }

  /// Adds a lane slot; false once [maxExtraSlots] is reached.
  bool addExtraSlot() {
    if (_extraSlots >= maxExtraSlots) return false;
    _extraSlots++;
    final lane = [..._state.lane, null];
    final next = _state.copyWith(lane: lane);
    _state = next.copyWith(status: Rules.evaluate(next));
    return true;
  }
}
