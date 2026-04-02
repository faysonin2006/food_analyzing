import 'dart:collection';

import '../../../repositories/app_repository.dart';

class LikeEntry {
  final int recipeId;
  final DateTime? createdAt;

  const LikeEntry({required this.recipeId, this.createdAt});
}

class LikesService {
  LikesService._();

  static final LikesService instance = LikesService._();

  final AppRepository _repository = AppRepository.instance;
  final Set<void Function()> _listeners = {};
  final Set<int> _inFlightRecipeIds = {};
  final List<LikeEntry> _entries = [];

  bool _loading = false;
  bool _loadedAtLeastOnce = false;

  bool get isLoading => _loading;
  bool get isLoadedAtLeastOnce => _loadedAtLeastOnce;
  UnmodifiableListView<LikeEntry> get entries => UnmodifiableListView(_entries);

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  bool isLiked(int recipeId) {
    return _entries.any((e) => e.recipeId == recipeId);
  }

  Future<void> ensureLoaded() async {
    if (_loadedAtLeastOnce || _loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _notify();
    try {
      final raw = await _repository.getLikedRecipes();
      final parsed = raw
          .map(_toLikeEntryOrNull)
          .whereType<LikeEntry>()
          .toList();

      parsed.sort((a, b) {
        final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

      _entries
        ..clear()
        ..addAll(parsed);
      _loadedAtLeastOnce = true;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<bool> like(int recipeId) async {
    if (_inFlightRecipeIds.contains(recipeId)) return false;
    if (isLiked(recipeId)) return true;

    _inFlightRecipeIds.add(recipeId);
    _entries.insert(
      0,
      LikeEntry(recipeId: recipeId, createdAt: DateTime.now()),
    );
    _notify();

    final ok = await _repository.likeRecipe(recipeId);
    if (!ok) {
      _entries.removeWhere((e) => e.recipeId == recipeId);
      _notify();
      _inFlightRecipeIds.remove(recipeId);
      return false;
    }

    _inFlightRecipeIds.remove(recipeId);
    return true;
  }

  Future<bool> unlike(int recipeId) async {
    if (_inFlightRecipeIds.contains(recipeId)) return false;
    if (!isLiked(recipeId)) return true;

    _inFlightRecipeIds.add(recipeId);
    final previous = _entries.firstWhere((e) => e.recipeId == recipeId);
    _entries.removeWhere((e) => e.recipeId == recipeId);
    _notify();

    final ok = await _repository.unlikeRecipe(recipeId);
    if (!ok) {
      _entries.insert(0, previous);
      _notify();
      _inFlightRecipeIds.remove(recipeId);
      return false;
    }

    _inFlightRecipeIds.remove(recipeId);
    return true;
  }

  Future<bool> toggle(int recipeId) async {
    if (isLiked(recipeId)) return unlike(recipeId);
    return like(recipeId);
  }

  LikeEntry? _toLikeEntryOrNull(Map<String, dynamic> raw) {
    final recipeId = _toInt(raw['recipeId'] ?? raw['recipe_id'] ?? raw['id']);
    if (recipeId == null || recipeId <= 0) return null;

    final createdRaw = raw['createdAt'] ?? raw['created_at'];
    DateTime? createdAt;
    if (createdRaw != null) {
      createdAt = DateTime.tryParse(createdRaw.toString());
    }

    return LikeEntry(recipeId: recipeId, createdAt: createdAt);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  void _notify() {
    for (final listener in _listeners.toList()) {
      listener();
    }
  }
}
