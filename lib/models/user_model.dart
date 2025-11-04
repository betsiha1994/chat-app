class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? profileImage;
  final bool? isOnline;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage,
    this.isOnline,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImage: data['profileImage'],
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'isOnline': isOnline ?? false,
    };
  }
}
