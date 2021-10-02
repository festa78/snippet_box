import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/authentication/sign_in_view.dart';
import 'package:myapp/models/user.dart';
import 'package:myapp/services/firebase_auth_service.dart';
import 'package:myapp/widgets/user_page.dart';

class SnippetBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (_) => FirebaseAuthService(),
        ),
        StreamProvider(
          initialData: null,
          create: (context) =>
              context.read<FirebaseAuthService>().onAuthStateChanged,
        ),
      ],
      child: LogInPage(),
    );
  }
}

class LogInPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snippet box',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<SnippetBoxUser>(
        builder: (_, user, __) {
          if (user == null) {
            return const SignInView();
          } else {
            return UserPage(title: 'Snippet box');
          }
        },
      ),
    );
  }
}
