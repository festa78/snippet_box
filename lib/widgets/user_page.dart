import 'package:flutter/material.dart';

import 'package:myapp/models/feed.dart';
import 'package:myapp/widgets/feed_list/feed_list_page.dart';
import 'package:myapp/widgets/saved_page.dart';
import 'package:myapp/widgets/voted_list_page.dart';

class UserPage extends StatefulWidget {
  final String title = 'Snippet Box';

  UserPage({Key key}) : super(key: key);

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  int _currentIndex = 0;
  final _pageWidgets = [
    SavedPage(),
    FeedListPage(
      rssUrlParser: RssUrlParser(),
    ),
    VotedListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pageWidgets.elementAt(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'News Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.thumb_up), label: 'Voted'),
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
