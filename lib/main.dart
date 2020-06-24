import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/firebase_auth_service.dart';
import 'authentication/sign_in_view.dart';
import 'models/user.dart';

import 'package:myapp/widgets/nav_drawer.dart';
import 'package:myapp/widgets/item_list.dart';
import 'package:myapp/widgets/item_editor.dart';

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
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snippet box',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<User>(
        builder: (_, user, __) {
          if (user == null) {
            return const SignInView();
            // return const SignInView();
          } else {
            return MyHomePage(title: 'Snippet box');
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final String tagPrefix = 'label:';

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

enum ArticleTypes {
  URL,
  PDF,
  TEXT,
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _queryTerms = [];
  List<String> _queryTags = ['__all__'];

  void _setQuery(String query) {
    setState(() {
      this._queryTags.clear();
      this._queryTerms.clear();

      query.split(' ').forEach((element) {
        if (element.startsWith(widget.tagPrefix)) {
          this._queryTags.add(element.replaceFirst(widget.tagPrefix, ''));
        } else {
          this._queryTerms.add(element);
        }
      });

      if (this._queryTags.isEmpty) {
        this._queryTags.add('__all__');
      }
    });
    print('tags: ${this._queryTags}');
    print('terms: ${this._queryTerms}');
  }

  _createDialogOption(
      BuildContext context, ArticleTypes articleType, String str) {
    return new SimpleDialogOption(
      child: new Text(str),
      onPressed: () {
        Navigator.pop(context, articleType);
      },
    );
  }

  _addUrlDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Provide URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(hintText: "Title"),
                ),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(hintText: "URL path"),
                ),
              ],
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text('Add'),
                onPressed: () async {
                  print(
                      'Add new title ${titleController.text} with article ${contentController.text}');
                  await Firestore.instance.collection('test_list').add({
                    'title': titleController.text,
                    'uri': contentController.text,
                    'tags': ['__all__'],
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.of(context).pop();
                },
              ),
              new FlatButton(
                child: new Text('CANCEL'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  _addArticleDialog(BuildContext context) {
    showDialog<ArticleTypes>(
      context: context,
      builder: (BuildContext context) => new SimpleDialog(
        title: new Text('Select the content type'),
        children: <Widget>[
          _createDialogOption(context, ArticleTypes.URL, 'Url'),
          _createDialogOption(context, ArticleTypes.TEXT, 'Text')
        ],
      ),
    ).then((value) {
      switch (value) {
        case ArticleTypes.URL:
          print('url');
          _addUrlDialog(context);
          break;
        case ArticleTypes.PDF:
          print('pdf');
          break;
        case ArticleTypes.TEXT:
          print('text');
          // TODO: switch to HTML editor.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LaunchTextEditor(
                initialTitle: 'New article',
                initialContent: 'New content',
              ),
            ),
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.power_settings_new,
              size: 24.0,
            ),
            onPressed: () {
              print('logout');
              context.read<FirebaseAuthService>().signOut();
            },
          ),
        ],
      ),
      drawer: NavDrawer(),
      body: Column(children: <Widget>[
        TextField(
          decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Input filter query. Ex) label:inbox kitten'),
          onSubmitted: (String value) => this._setQuery(value),
        ),
        ItemList(this._queryTags, this._queryTerms),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          this._addArticleDialog(context);
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
