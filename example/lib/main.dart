import 'package:flutter/material.dart';
import 'package:update_version/update_version.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();

  }

  Future checkVersion() async {
    VersionStatus? versionStatus = await new UpdateVersion().getVersionStatus();
    if (versionStatus != null && versionStatus.canUpdate == true) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Need to update'),
            content: Text('You can now update this app from ${versionStatus.localVersion} to ${versionStatus.storeVersion}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                },
                  child: Text('Later')
              ),
              TextButton(
                onPressed: () {
                  new UpdateVersion().launchAppStore(versionStatus.appStoreLink);
                },
                child: Text('Update')
              ),
            ]
          );
        }
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Example App"),
      ),
    );
  }
}
