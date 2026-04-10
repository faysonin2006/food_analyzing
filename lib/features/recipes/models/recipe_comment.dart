part of 'models.dart';

class RecipeComment {
  final int id;
  final int recipeId;
  final int? parentCommentId;
  final String authorName;
  final String body;
  final DateTime? createdAt;
  final int likeCount;
  final bool likedByMe;
  final int replyCount;
  final List<RecipeComment> replies;

  const RecipeComment({
    required this.id,
    required this.recipeId,
    this.parentCommentId,
    required this.authorName,
    required this.body,
    this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.replyCount = 0,
    this.replies = const <RecipeComment>[],
  });

  RecipeComment copyWith({
    int? id,
    int? recipeId,
    int? parentCommentId,
    bool clearParentCommentId = false,
    String? authorName,
    String? body,
    DateTime? createdAt,
    int? likeCount,
    bool? likedByMe,
    int? replyCount,
    List<RecipeComment>? replies,
  }) {
    return RecipeComment(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      parentCommentId: clearParentCommentId
          ? null
          : (parentCommentId ?? this.parentCommentId),
      authorName: authorName ?? this.authorName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
    );
  }

  factory RecipeComment.fromDynamic(dynamic raw) {
    final decoded = _decodeJsonString(raw);
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
    final timestamp =
        map['createdAt']?.toString() ??
        map['created_at']?.toString() ??
        map['timestamp']?.toString();
    return RecipeComment(
      id: _toInt(map['id']) ?? 0,
      recipeId: _toInt(map['recipeId'] ?? map['recipe_id']) ?? 0,
      parentCommentId: _toInt(
        map['parentCommentId'] ?? map['parent_comment_id'],
      ),
      authorName:
          _cleanText(
            map['authorName']?.toString() ?? map['author_name']?.toString(),
          ) ??
          'Anonymous',
      body:
          _cleanText(map['body']?.toString() ?? map['text']?.toString()) ?? '',
      createdAt: timestamp == null ? null : DateTime.tryParse(timestamp),
      likeCount: _toInt(map['likeCount'] ?? map['like_count']) ?? 0,
      likedByMe: map['likedByMe'] == true || map['liked_by_me'] == true,
      replyCount: _toInt(map['replyCount'] ?? map['reply_count']) ?? 0,
      replies: listFromDynamic(map['replies']),
    );
  }

  static List<RecipeComment> listFromDynamic(dynamic raw) {
    final decoded = _decodeJsonString(raw);
    if (decoded is! List) return const <RecipeComment>[];
    return decoded
        .map(RecipeComment.fromDynamic)
        .where((item) => item.body.trim().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'recipeId': recipeId,
    if (parentCommentId != null) 'parentCommentId': parentCommentId,
    'authorName': authorName,
    'body': body,
    'likeCount': likeCount,
    'likedByMe': likedByMe,
    'replyCount': replyCount,
    'replies': replies.map((item) => item.toJson()).toList(),
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
  };
}
