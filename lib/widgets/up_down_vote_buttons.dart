import 'package:flutter/material.dart';

class UpDownVoteButtons extends StatefulWidget {
  final int voteStateInit;

  UpDownVoteButtons({@required this.voteStateInit});

  @override
  UpDownVoteButtonsState createState() =>
      UpDownVoteButtonsState(voteState: this.voteStateInit);
}

class UpDownVoteButtonsState extends State<UpDownVoteButtons> {
  // <0: negative, 0: not selected, >0: positive.
  int voteState;

  UpDownVoteButtonsState({@required this.voteState});

  @override
  Widget build(BuildContext context) {
    return ButtonBar(
      children: [
        IconButton(
          icon: Icon(Icons.thumb_up),
          color: this.voteState > 0 ? Colors.blueAccent : Colors.grey,
          onPressed: () {
            setState(() {
              if (this.voteState > 0) {
                this.voteState = 0;
              } else {
                this.voteState = 1;
              }
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.thumb_down),
          color: this.voteState < 0 ? Colors.blueAccent : Colors.grey,
          onPressed: () {
            setState(() {
              if (this.voteState < 0) {
                this.voteState = 0;
              } else {
                this.voteState = -1;
              }
            });
          },
        ),
      ],
    );
  }
}
