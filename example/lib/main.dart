import 'package:flutster/flutster.dart';
import 'package:flutter/material.dart';

void main() {
  const flutsterKey = String.fromEnvironment("flutsterKey");
  const flutsterUser = String.fromEnvironment("flutsterUser");
  const flutsterUrl = String.fromEnvironment("flutsterUrl");
  if (flutsterKey.isNotEmpty &&
      flutsterUser.isNotEmpty &&
      flutsterUrl.isNotEmpty) {
    FlutsterTestRecord.defaultRecord.apiUrl = flutsterUrl;
    FlutsterTestRecord.defaultRecord.apiUser = flutsterUser;
    FlutsterTestRecord.defaultRecord.apiKey = flutsterKey;
  } else {
    FlutsterTestRecord.defaultRecord.apiUrl = "https://flutster.com";
    FlutsterTestRecord.defaultRecord.apiUser = "YOUR FLUTSTER USER";
    FlutsterTestRecord.defaultRecord.apiKey = "YOUR FLUTSTER API KEY";
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutster Recorder Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SafeArea(
        child: MyHomePage(title: 'Flutster Recorder Example Home Page'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool color = false;

  @override
  Widget build(BuildContext context) {
    return FlutsterScaffold(
      name: "exampleFlutsterTestRecorder",
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            Card(
              color: color ? Colors.yellow : Colors.white,
              child: IconButton(
                icon: const Icon(Icons.add_reaction),
                onPressed: () {
                  setState(() {
                    color = !color;
                  });
                },
              ),
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: "test",
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }
}
