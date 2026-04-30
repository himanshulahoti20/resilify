// Example: using `package:resilify` with Dio for production-grade requests.
//
// Run with: `dart run example/dio_example.dart`

import 'package:resilify/resilify_dio.dart';

class User {
  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final int id;
  final String name;
  final String email;

  @override
  String toString() => 'User(#$id, $name <$email>)';
}

Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 10),
    ),
  )..interceptors.add(ResultLoggerInterceptor(logHeaders: false));

  final api = DioResultHandler(dio);

  final result = await api.get<User>(
    '/users/1',
    parser: (data) => User.fromJson(data! as Map<String, dynamic>),
  );

  result
    ..onSuccess((u) => print('user: $u'))
    ..onError((f) => print('failure: ${f.message}'));
}
