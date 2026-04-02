import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SearchHistoryEntry {
  final int id;
  final String queryText;
  final String? titleQuery;
  final String? categoryQuery;
  final String? dietQuery;
  final String lang;
  final DateTime createdAt;

  const SearchHistoryEntry({
    required this.id,
    required this.queryText,
    required this.titleQuery,
    required this.categoryQuery,
    required this.dietQuery,
    required this.lang,
    required this.createdAt,
  });

  String get displayText => queryText.trim();

  factory SearchHistoryEntry.fromMap(Map<String, Object?> map) {
    return SearchHistoryEntry(
      id: (map['id'] as num).toInt(),
      queryText: (map['query_text'] as String?) ?? '',
      titleQuery: map['title_query'] as String?,
      categoryQuery: map['category_query'] as String?,
      dietQuery: map['diet_query'] as String?,
      lang: ((map['lang'] as String?) ?? 'EN').toUpperCase(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class SearchHistoryDraft {
  final String queryText;
  final String? titleQuery;
  final String? categoryQuery;
  final String? dietQuery;
  final String lang;

  const SearchHistoryDraft({
    required this.queryText,
    required this.lang,
    this.titleQuery,
    this.categoryQuery,
    this.dietQuery,
  });
}

class SearchHistoryLocalDb {
  SearchHistoryLocalDb._();

  static final SearchHistoryLocalDb instance = SearchHistoryLocalDb._();

  static const _dbName = 'food_analyzing_local.db';
  static const _table = 'search_history';
  static const _maxRowsPerLang = 60;

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    final path = p.join(root, _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          create table $_table (
            id integer primary key autoincrement,
            query_text text not null,
            query_text_norm text not null,
            title_query text,
            category_query text,
            diet_query text,
            lang text not null,
            created_at integer not null
          )
        ''');
        await db.execute(
          'create unique index idx_search_history_norm_lang on $_table(query_text_norm, lang)',
        );
        await db.execute(
          'create index idx_search_history_created_at on $_table(created_at desc)',
        );
      },
    );
    return _db!;
  }

  String _normalize(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String? _cleanNullable(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> save(SearchHistoryDraft draft) async {
    final normalized = _normalize(draft.queryText);
    if (normalized.isEmpty) return;
    final db = await _database();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lang = draft.lang.trim().toUpperCase();

    final payload = <String, Object?>{
      'query_text': draft.queryText.trim(),
      'query_text_norm': normalized,
      'title_query': _cleanNullable(draft.titleQuery),
      'category_query': _cleanNullable(draft.categoryQuery),
      'diet_query': _cleanNullable(draft.dietQuery),
      'lang': lang,
      'created_at': nowMs,
    };

    final updated = await db.update(
      _table,
      payload,
      where: 'query_text_norm = ? and lang = ?',
      whereArgs: [normalized, lang],
    );
    if (updated == 0) {
      await db.insert(_table, payload);
    }

    final rows = await db.query(
      _table,
      columns: const ['id'],
      where: 'lang = ?',
      whereArgs: [lang],
      orderBy: 'created_at desc',
    );
    if (rows.length <= _maxRowsPerLang) return;

    final idsToDelete = rows.skip(_maxRowsPerLang).map((m) => m['id']).toList();
    if (idsToDelete.isEmpty) return;
    final placeholders = List.filled(idsToDelete.length, '?').join(',');
    await db.delete(
      _table,
      where: 'id in ($placeholders)',
      whereArgs: idsToDelete,
    );
  }

  Future<List<SearchHistoryEntry>> listRecent({
    required String lang,
    int limit = 20,
  }) async {
    final db = await _database();
    final normalizedLang = lang.trim().toUpperCase();
    final rows = await db.query(
      _table,
      where: 'lang = ?',
      whereArgs: [normalizedLang],
      orderBy: 'created_at desc',
      limit: limit,
    );
    return rows.map(SearchHistoryEntry.fromMap).toList();
  }

  Future<void> deleteById(int id) async {
    final db = await _database();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearByLang(String lang) async {
    final db = await _database();
    await db.delete(
      _table,
      where: 'lang = ?',
      whereArgs: [lang.trim().toUpperCase()],
    );
  }
}
