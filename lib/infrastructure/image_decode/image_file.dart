
class ImageFile {
  final String? name;
  final DateTime? createTime;
  final DateTime? lastEditTime;
  final String? author;
  final String? comment;

  final ImageExt? ext;
  final int? size;
  ImageFile({
    this.name,
    this.createTime,
    this.lastEditTime,
    this.author,
    this.comment,
    required this.ext,
    this.size,
  });

  

  ImageFile copyWith({
    String? name,
    DateTime? createTime,
    DateTime? lastEditTime,
    String? author,
    String? comment,
    ImageExt? ext,
    int? size,
  }) {
    return ImageFile(
      name: name ?? this.name,
      createTime: createTime ?? this.createTime,
      lastEditTime: lastEditTime ?? this.lastEditTime,
      author: author ?? this.author,
      comment: comment ?? this.comment,
      ext: ext ?? this.ext,
      size: size ?? this.size,
    );
  }

  @override
  String toString() {
    return 'ImageFile(name: $name, createTime: $createTime, lastEditTime: $lastEditTime, author: $author, comment: $comment, ext: $ext, size: $size)';
  }

}

enum ImageExt{
  jpeg,
  png,
  gif,
  webp,
  avif,
  svg,
  unknown,
}