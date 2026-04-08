class ProfileModel {
  final String id;
  final String username;
  final String publicKey;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.publicKey,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      publicKey: json['public_key'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'public_key': publicKey,
        'created_at': createdAt.toIso8601String(),
      };
}
