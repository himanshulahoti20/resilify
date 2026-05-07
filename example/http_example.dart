// Example: using `package:resilify` with `package:http` for a quick prototype.
//
// Run with: `dart run example/http_example.dart`

import 'package:resilify/resilify_http.dart';

class Post {
  Post({required this.id, required this.title});

  factory Post.fromJson(Map<String, dynamic> json) =>
      Post(id: json['id'] as int, title: json['title'] as String);

  final int id;
  final String title;

  @override
  String toString() => 'Post(#$id, $title)';
}

Future<void> main() async {
  final api = HttpResultHandler(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    defaultHeaders: const {'Accept': 'application/json'},
  );

  final result = await api.get<List<Post>>(
    '/posts',
    queryParameters: const {'userId': 1},
    parser: (json) => (json! as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList(growable: false),
  );

  result.when(
    success: (posts) => print('fetched ${posts.length} posts'),
    error: (failure) => print('failed: $failure'),
  );

  api.close();
}
