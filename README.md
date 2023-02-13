# Flutster

Easy Flutter app integration testing automation as replayable records.
Conduct integration testing by recording user events and comparing widget screenshots.

## Platforms

Flutster has only been tested with Android.

## Example

An example of use for this plugin is available under the `example` folder.

## Dependency
Add to pubspec.yaml
```
dependencies:
  flutster: ^1.0.1
```

Import:
```
import 'package:flutster/flutster.dart';
```

## How to use
1)
Method One:
Replace or place one Scaffold per page you want to test with a FlutsterScaffold. For example:
```
   return FlutsterScaffold(
      name: "myUniqueWidgetName",
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ...
    );
```
Method Two:
Create the FlutsterTestRecorder and reference the widgets to test. 
```
FlutsterTestRecorder(
  name: "myUniqueWidgetName",
  child: myWidget,
)
```
2)
Once the Flutster plugin is integrated in your Android application, run the application either on an Android emulator or on a physical device with the help of scrcpy.

3)
Use the Flutster menu to record widgets. Interact with your application to record user events. Store and playback recordings to test. 

## Documentation

Flutster documentation is available at [site.flutster.com](https://site.flutster.com).

## Feature requests/comments/questions/bugs

Feel free to log your feature requests/comments/questions/bugs here:
https://github.com/jod-li/flutster/issues

## Contributions

We would be happy to merge pull request proposals provided that:
* they don't break the compilation
* they provide the relevant adaptations to documentation
* they bring value
* they don't completely transform the code
* they are readable

Contributions and forks are very welcome!

In your pull request, feel free to add your line in the contributors section below:

### Contributors

* [jod.li](https://github.com/jod-li/)

## CI/CD

Continuous integration/deployment status: ![CI-CD](https://github.com/jod-li/flutster/workflows/CI-CD/badge.svg)
