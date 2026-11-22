import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/id_generator.dart';
import '../models/tag_model.dart';

/// Repository for managing dual-color category tags.
class TagRepository {
  final AppDatabase _database;

  TagRepository(this._database);

  Future<List<TagModel>> getAllTags() async {
    final db = await _database.database;
    final rows = await db.query(
      'tags',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(TagModel.fromMap).toList();
  }

  Future<TagModel> createTag({
    required String name,
    required String lightColorHex,
    required String darkColorHex,
  }) async {
    final db = await _database.database;
    final existing = await getAllTags();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final tag = TagModel(
      id: IdGenerator.next('tag'),
      name: name.trim(),
      lightColorHex: lightColorHex,
      darkColorHex: darkColorHex,
      sortOrder: nextOrder,
    );

    await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return tag;
  }

  Future<void> updateTag(TagModel tag) async {
    final db = await _database.database;
    await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  /// Counts how many tasks currently use [tagId] as their primary tag.
  Future<int> countPrimaryTasks(String tagId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM tasks WHERE primary_tag_id = ?',
      [tagId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Deletes [tagId]. Throws [StateError] if any task still uses it as primary tag.
  Future<void> deleteTag(String tagId) async {
    final primaryCount = await countPrimaryTasks(tagId);
    if (primaryCount > 0) {
      throw StateError('该标签仍被 $primaryCount 个事项用作主标签，请先更改主标签后再删除。');
    }
    final db = await _database.database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }
}
