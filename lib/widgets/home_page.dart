import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/user.dart';
import 'package:myapp/services/firebase_auth_service.dart';
import 'package:myapp/widgets/nav_drawer.dart';
import 'package:myapp/widgets/item_list.dart';
import 'package:myapp/widgets/item_editor.dart';
import 'package:myapp/widgets/feed.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  final _pageWidgets = [
    SavedPage(title: 'Saved page'),
    FeedListPage(
      title: 'News feed page',
      rssUrlParser: RssUrlParser(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pageWidgets.elementAt(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'News Feed'),
        ],
        currentIndex: _currentIndex,
        fixedColor: Colors.blueAccent,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  void _onItemTapped(int index) => setState(() => _currentIndex = index);
}

class SavedPage extends StatefulWidget {
  SavedPage({Key key, this.title}) : super(key: key);

  final String title;
  final String tagPrefix = 'label:';

  @override
  _SavedPageState createState() => _SavedPageState();
}

enum ArticleTypes {
  URL,
  PDF,
  TEXT,
}

class _SavedPageState extends State<SavedPage> {
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
              new TextButton(
                child: new Text('Add'),
                onPressed: () async {
                  print(
                      'Add new title ${titleController.text} with article ${contentController.text}');
                  final userData = Provider.of<MyUser>(context);
                  await FirebaseFirestore.instance
                      .collection('user_data')
                      .doc(userData.uid)
                      .collection('snippets')
                      .add({
                    'title': titleController.text,
                    'uri': contentController.text,
                    'tags': ['__all__'],
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.of(context).pop();
                },
              ),
              new TextButton(
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
