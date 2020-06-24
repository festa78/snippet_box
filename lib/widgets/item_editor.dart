import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LaunchTextEditor extends StatelessWidget {
  LaunchTextEditor({this.initialTitle, this.initialContent});

  final String initialTitle;
  final String initialContent;

  @override
  Widget build(BuildContext context) {
    final titleController = TextEditingController(text: this.initialTitle);
    final contentController = TextEditingController(text: this.initialContent);

    return Scaffold(
      appBar: AppBar(
        title: TextField(controller: titleController),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.update,
              size: 24.0,
            ),
            onPressed: () async {
              print('title: ${titleController.text}');
              print('content: ${contentController.text}');
              await Firestore.instance.collection('test_list').add({
                'title': titleController.text,
                'uri': '',
                'html': '',
                'text': contentController.text,
                'tags': ['__all__'],
                'timestamp': FieldValue.serverTimestamp(),
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: TextField(
        controller: contentController,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter text',
        ),
        keyboardType: TextInputType.multiline,
        maxLines: null,
      ),
    );
  }
}
