import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/services/firebase_auth_service.dart';
import 'package:myapp/authentication/sign_in_view.dart';
import 'package:myapp/models/user.dart';
import 'package:myapp/widgets/home_page.dart';

void main() => runApp(
      MultiProvider(
        providers: [
          Provider(
            create: (_) => FirebaseAuthService(),
          ),
          StreamProvider(
            create: (context) =>
                context.read<FirebaseAuthService>().onAuthStateChanged,
          ),
        ],
        child: MyApp(),
      ),
    );

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snippet box',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<User>(
        builder: (_, user, __) {
          if (user == null) {
            return const SignInView();
          } else {
            return MyHomePage(title: 'Snippet box');
          }
        },
      ),
    );
  }
}
