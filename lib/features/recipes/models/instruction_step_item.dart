part of 'models.dart';

class InstructionStepItem {
  final int? position;
  final String text;
  final String? durationHint;
  final String? temperatureHint;
  final List<String> ingredients;
  final List<String> equipment;
  final Map<String, String> ingredientImages;
  final Map<String, String> equipmentImages;
  final String? section;

  InstructionStepItem({
    this.position,
    required this.text,
    this.durationHint,
    this.temperatureHint,
    this.ingredients = const [],
    this.equipment = const [],
    this.ingredientImages = const {},
    this.equipmentImages = const {},
    this.section,
  });

  static List<InstructionStepItem> listFromDynamic(dynamic raw) {
    final list = _asMapList(raw);
    return list.map((m) {
      return InstructionStepItem(
        position: _toInt(m['position']),
        text: (m['text'] ?? '').toString(),
        durationHint:
            m['durationHint']?.toString() ?? m['duration_hint']?.toString(),
        temperatureHint:
            m['temperatureHint']?.toString() ??
            m['temperature_hint']?.toString(),
        ingredients: _namesFromDynamicList(m['ingredients']),
        equipment: _namesFromDynamicList(m['equipment']),
        ingredientImages: _imageMapFromDynamicList(m['ingredients']),
        equipmentImages: _imageMapFromDynamicList(m['equipment']),
        section: m['section']?.toString(),
      );
    }).toList();
  }

  static List<String> _namesFromDynamicList(dynamic raw) {
    if (raw is! List) return const [];

    final out = <String>[];
    for (final e in raw) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final name = (m['name'] ?? m['ingredient'] ?? '').toString().trim();
        if (name.isNotEmpty) out.add(name);
      } else {
        final name = e.toString().trim();
        if (name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }

  static Map<String, String> _imageMapFromDynamicList(dynamic raw) {
    if (raw is! List) return const {};

    final out = <String, String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final name = (m['name'] ?? m['ingredient'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final image = (m['imageUrl'] ?? m['image_url'] ?? m['image'] ?? '')
          .toString()
          .trim();
      if (image.isEmpty) continue;
      out[name] = image;
    }
    return out;
  }
}
