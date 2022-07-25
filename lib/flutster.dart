/// [flutster] library intended use is for Android.
/// Refer to https://flutster.com for more details on how to use this plugin.
library flutster;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui show Image;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_compare/image_compare.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The [latestState] is teh latest [FlutsterTestRecorderState] started.
/// This is used while running the test.
FlutsterTestRecorderState? latestState;

/// Set [displayFlutsterButton] to false if you temporarily don't want to
/// display the flutster button
bool displayFlutsterButton = true;

extension on Duration {
  /// [duration.toStringYouHave()] displays the duration in a human way.
  String toStringYouHave() {
    var seconds = inSeconds;
    final days = seconds ~/ Duration.secondsPerDay;
    seconds -= days * Duration.secondsPerDay;
    final hours = seconds ~/ Duration.secondsPerHour;
    seconds -= hours * Duration.secondsPerHour;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    seconds -= minutes * Duration.secondsPerMinute;

    final List<String> tokens = [];
    if (days != 0) {
      tokens.add('${days}d');
    }
    if (tokens.isNotEmpty || hours != 0) {
      tokens.add('${hours}h');
    }
    if (tokens.isNotEmpty || minutes != 0) {
      tokens.add('${minutes}m');
    }
    tokens.add('${seconds}s');

    return "${tokens.join(':')}.${(inMilliseconds % 1000).toString().padLeft(3, "0")}";
  }
}

extension on Map<String, dynamic> {
  /// [getIfNotNull] returns null if the key doesn't exist.
  /// Optionally returns the result of builder.
  dynamic getIfNotNull(String key, [dynamic Function(dynamic value)? builder]) {
    if (!containsKey(key)) {
      return (null);
    }
    if (builder == null) {
      return (this[key]);
    }
    return (builder(this[key]));
  }
}

/// A [FlutsterTestRecord] mainly holds the list of test events.
class FlutsterTestRecord {
  /// The [defaultRecord] can be used in case no FlutsterTestRecord is given.
  static FlutsterTestRecord defaultRecord = FlutsterTestRecord();

  /// [firstRecordingStart] stores when the recording started.
  DateTime? firstRecordingStart;

  /// [_recording] whether or not we are recording.
  bool _recording = false;

  /// [expect] is used while running the test to report on the result.
  Function(dynamic actual, dynamic matcher, {String? reason, dynamic skip})?
      expect;

  /// [apiUrl], [apiUser], [apiKey optionally set access to https://flutster.com
  String? apiUrl, apiUser, apiKey;

  /// [id] is the https://flutster.com test record id.
  int? id;

  /// [apiVersion] as set by https://flutster.com
  final String apiVersion = "1";

  /// Should be set to false on production environments so that the floating
  /// button is not displayed.
  bool active = true;

  /// [buttonSize] allows tweaking the size of the Flutster floating button.
  double? buttonSize;

  /// [recording] is set to true when we record the test.
  set recording(bool value) {
    if (value && !_recording && firstRecordingStart == null) {
      firstRecordingStart = DateTime.now();
    }
    if (!value && _recording && firstRecordingStart != null && events.isEmpty) {
      firstRecordingStart = null;
    }
    if (events.isNotEmpty && value) {
      events.last.resumeTime = DateTime.now();
    }
    _recording = value;
  }

  /// [recording] returns true when we record the test.
  bool get recording {
    return (_recording);
  }

  /// [testName] optionally makes it easier to find the test.
  String testName = "";

  /// [events] are the steps of the test.
  List<FlutsterTestEvent> events = [];

  /// [FlutsterTestRecord] takes parameters described as fields of the class.
  FlutsterTestRecord({
    String? testName,
    this.firstRecordingStart,
    List<FlutsterTestEvent>? events,
    this.apiUrl = "https://flutster.com",
    this.apiUser,
    this.apiKey,
    this.active = true,
  }) {
    assert(
        (apiUser == null && apiKey == null) ||
            (apiUser != null && apiKey != null),
        "apiUrl, apiUser and apiKey must be given together to work");
    if (testName != null) {
      this.testName = testName;
    }
    if (events != null) {
      this.events = events;
    }
  }

  /// [testNameValidator] returns null if the given [testName] is valid.
  static String? testNameValidator(String? testName) {
    if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(testName ?? "") &&
        (testName ?? "").isNotEmpty) {
      return ("No special character allowed");
    }
    return (null);
  }

  /// [widgetNameValidator] returns null if the given [widgetName] is valid.
  static String? widgetNameValidator(String? widgetName) {
    if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(widgetName ?? "") &&
        (widgetName ?? "").isNotEmpty) {
      return ("No special character allowed");
    }
    return (null);
  }

  /// [uIntValidator] returns null if the given [uInt] is valid.
  static String? uIntValidator(String? uInt) {
    if (uInt == null || uInt.isEmpty) {
      return ("Cannot be empty");
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(uInt) && (uInt).isNotEmpty) {
      return ("Only a positive integer number is allowed");
    }
    return (null);
  }

  /// [pctValidator] returns null if the given [doubleString] is a valid
  /// percentage.
  static String? pctValidator(String? doubleString) {
    if (doubleString == null || doubleString.isEmpty) {
      return ("Cannot be empty");
    }
    if (!RegExp(r'^[0-9]+.?[0-9]*$').hasMatch(doubleString) &&
        (doubleString).isNotEmpty) {
      return ("Only a positive number <= 100 is allowed");
    }
    if (double.tryParse(doubleString)! > 100) {
      return ("Only a positive number <= 100 is allowed");
    }
    return (null);
  }

  /// [uDoubleValidator] returns null if the given [doubleString] is valid.
  static String? uDoubleValidator(String? doubleString) {
    if (doubleString == null || doubleString.isEmpty) {
      return ("Cannot be empty");
    }
    if (!RegExp(r'^[0-9]+.?[0-9]*$').hasMatch(doubleString) &&
        (doubleString).isNotEmpty) {
      return ("Only a positive number is allowed");
    }
    return (null);
  }

  /// [ratioValidator] returns null if the given [doubleString] is valid.
  static String? ratioValidator(String? doubleString) {
    if (doubleString == null || doubleString.isEmpty) {
      return ("Cannot be empty");
    }
    if (!RegExp(r'^[01]+.?[0-9]*$').hasMatch(doubleString) &&
        (doubleString).isNotEmpty) {
      return ("Only a positive number <= 1 is allowed");
    }
    if (double.tryParse(doubleString)! > 1) {
      return ("Only a positive number <= 1 is allowed");
    }
    return (null);
  }

  /// [tapUp] records the end of a tap.
  tapUp(Offset tapStop, {Duration? tapDuration, DateTime? time}) {
    if (!recording) {
      return;
    }
    assert(tapDuration == null || time == null,
        "At least one of tapDuration or time must be null.");
    if (events.last.type != FlutsterTestEventType.tap) {
      throw Exception("Trying to tap up while latest event is not a tap.");
    }
    Duration? duration;
    if (tapDuration != null) {
      duration = tapDuration;
    } else {
      duration = durationToLastEvent(time);
    }
    events.last.tapUp(tapStop, tapDuration: duration);
  }

  /// [add] adds an event to the list of events.
  add(FlutsterTestEvent flutsterTestEvent) {
    if (!recording) {
      return;
    }
    flutsterTestEvent.waitDuration = durationToLastEvent();
    if (events.isNotEmpty &&
        events.last.type == FlutsterTestEventType.tap &&
        events.last.tapStop == null) {
      tapUp(events.last.tapStart!, tapDuration: Duration.zero);
    }
    events.add(flutsterTestEvent);
  }

  /// [durationToLastEvent] returns the duration since the last recorded event.
  /// If dateTime is given, or now otherwise.
  /// If no event was recorded, it takes [firstRecordingStart] instead.
  Duration durationToLastEvent([DateTime? dateTime]) {
    if (events.isEmpty) {
      return ((dateTime ?? DateTime.now())
          .difference(firstRecordingStart ?? DateTime.now()));
    }
    return ((dateTime ?? DateTime.now())
        .difference(events.last.resumeTime ?? events.last.time));
  }

  int findEventIndex(FlutsterTestEvent flutsterTestEvent) {
    return events.indexOf(flutsterTestEvent);
  }

  /// [findPreviousEvent] returns the event that was recorded just before the
  /// given event.
  /// Returns null in case the given event was the first one.
  FlutsterTestEvent? findPreviousEvent(FlutsterTestEvent flutsterTestEvent) {
    int index = findEventIndex(flutsterTestEvent);
    if (index == 0) {
      return (null);
    }
    return (events[index - 1]);
  }

  /// [findNextEvent] returns the event that was recorded right after the given
  /// one.
  /// Returns null in case the given event was the last one.
  FlutsterTestEvent? findNextEvent(FlutsterTestEvent flutsterTestEvent) {
    int index = findEventIndex(flutsterTestEvent);
    if (index == events.length - 1) {
      return (null);
    }
    return (events[index + 1]);
  }

  /// [deleteEvent] removes the given event from the list of recorded events.
  void deleteEvent(FlutsterTestEvent event) {
    events.remove(event);
  }

  /// [clear] flushes the events, resets the test name, api id,
  /// [firstRecordingStart] and stops the recording.
  void clear() {
    id = null;
    testName = "";
    firstRecordingStart = null;
    _recording = false;
    events.clear();
  }

  /// [isCleared] returns true in case the record is in a state that would be
  /// equivalent if [clear] was called.
  bool isCleared() {
    return (testName.isEmpty &&
        firstRecordingStart == null &&
        !_recording &&
        events.isEmpty);
  }

  /// [toMap] returns a Map of the record including the events.
  /// If [alternateEvents] is given, the events are replaced in the returned map
  /// by this given list.
  Map<String, dynamic> toMap({List<FlutsterTestEvent>? alternateEvents}) {
    alternateEvents ??= events;
    Map<String, dynamic> ret = {
      "testName": testName,
    };
    if (firstRecordingStart?.millisecondsSinceEpoch != null) {
      ret.addAll({
        "firstRecordingStart": firstRecordingStart?.millisecondsSinceEpoch,
      });
    }
    ret.addAll({
      "events": alternateEvents.map((e) => e.toMap()).toList(),
    });
    return (ret);
  }

  /// [toJson] returns the record as a json string.
  String toJson({List<FlutsterTestEvent>? alternateEvents}) {
    return (jsonEncode(toMap(alternateEvents: alternateEvents)));
  }

  /// [fromJson] returns the record built from the interpreted given json.
  factory FlutsterTestRecord.fromJson(
    String json, {
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
  }) {
    return (FlutsterTestRecord.fromMap(
      jsonDecode(json),
      flutsterTestRecorderState: flutsterTestRecorderState,
      tester: tester,
    ));
  }

  /// [fromMap] returns the record built from the given map.
  factory FlutsterTestRecord.fromMap(
    Map<String, dynamic> map, {
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
  }) {
    FlutsterTestRecord ret = FlutsterTestRecord().fromMap(
      map,
      flutsterTestRecorderState: flutsterTestRecorderState,
      tester: tester,
    );
    return (ret);
  }

  /// [fromJson] builds the record from the interpreted given json.
  fromJson(
    String json, {
    Function(
      dynamic actual,
      dynamic matcher, {
      String? reason,
      dynamic skip,
    })?
        expect,
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
  }) {
    this.expect = expect;
    fromMap(
      jsonDecode(json),
      flutsterTestRecorderState: flutsterTestRecorderState,
      tester: tester,
    );
  }

  /// [fromApi] builds the record from the https://flutster.com API details.
  Future<String> fromApi(
    int trid, {
    Function(
      dynamic actual,
      dynamic matcher, {
      String? reason,
      dynamic skip,
    })?
        expect,
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
    int retries = 10,
  }) async {
    if (apiKey == null ||
        apiUser == null ||
        apiUrl == null ||
        apiKey!.isEmpty ||
        apiUser!.isEmpty ||
        apiUrl!.isEmpty) {
      return ("API load is only possible if apiKey, apiUser and apiUrl are "
          "provided");
    }
    String? ret;
    Map<String, String> headers = {
      "v": apiVersion,
    };
    Map<String, String> data = {
      "api": "tr",
    };
    data["tr"] = "readContent";
    data["trid"] = trid.toString();
    data["u"] = apiUser!;
    data["ak"] = apiKey!;
    String? res = await send(
      apiUrl!,
      data,
      headers: headers,
      timeoutMS: 10000,
    );
    if (res == null) {
      ret = apiCallResultToMessage(res, "Error on API test record load");
    } else {
      if (res.isNotEmpty && res.startsWith("{")) {
        if (res.substring(1, 10).contains("error")) {
          var resMap = jsonDecode(res);
          ret = "Error loading API test record: ${resMap["error"]} "
              "${resMap["message"]}";
        } else {
          fromJson(
            res,
            expect: expect,
            flutsterTestRecorderState: flutsterTestRecorderState,
            tester: tester,
          );
          id = trid;
          return ("Test record loaded from API");
        }
      }
    }
    ret ??=
        "Failed to load API test record with this response from server: ${res ?? ""}";
    if (retries > 0) {
      return (await fromApi(
        trid,
        expect: expect,
        flutsterTestRecorderState: flutsterTestRecorderState,
        tester: tester,
        retries: retries - 1,
      ));
    }
    return (ret);
  }

  /// [fromMap] builds the record from the given map.
  fromMap(
    Map<String, dynamic> map, {
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
  }) {
    if (flutsterTestRecorderState == null && tester == null) {
      throw Exception("Loading a test is only possible with either "
          "flutsterTestRecorderState or tester not null");
    }
    clear();
    testName = map["testName"] ?? "";
    firstRecordingStart = map.getIfNotNull("firstRecordingStart",
        (value) => DateTime.fromMillisecondsSinceEpoch(value));
    List<dynamic> eventsList = map["events"];
    events = eventsList
        .map((value) => FlutsterTestEvent.fromMap(
              value,
              flutsterTestRecorderState: flutsterTestRecorderState,
              tester: tester,
            ))
        .toList();
  }

  /// [share] is what is called when the user wants to share the record json.
  void share(
    BuildContext context,
  ) {
    DateTime startDt = DateTime.now();
    Share.shareWithResult(
      toJson(),
      // "example",
      subject: testName,
    ).then((ShareResult result) {
      bool fallback = true;
      if (DateTime.now().difference(startDt) >
          const Duration(milliseconds: 1000)) {
        fallback = false;
      }
      switch (result.status) {
        case ShareResultStatus.unavailable:
          if (!fallback) {
            FlutsterTestRecorderState.snackStatic(
              "Failed to share",
              context,
            );
          }
          break;
        case ShareResultStatus.dismissed:
          if (!fallback) {
            FlutsterTestRecorderState.snackStatic(
              "Share dismissed",
              context,
            );
          }
          break;
        case ShareResultStatus.success:
        default:
          fallback = false;
          break;
      }
      if (fallback) {
        shareAsFile(context);
      }
    });
  }

  /// [shareAsFile] is a fallback in case share didn't work.
  void shareAsFile(
    BuildContext context,
  ) {
    var dir = Directory.systemTemp.createTempSync();
    String path = "${dir.path}/$testName-flutster.txt";
    File temp = File(path);
    temp.createSync();
    temp.writeAsString(toJson()).whenComplete(() {
      Share.shareFilesWithResult(
        [path],
        subject: testName,
      ).then((ShareResult result) {
        switch (result.status) {
          case ShareResultStatus.unavailable:
            FlutsterTestRecorderState.snackStatic(
              "Failed to share",
              context,
            );
            break;
          case ShareResultStatus.dismissed:
            FlutsterTestRecorderState.snackStatic(
              "Share dismissed",
              context,
            );
            break;
          case ShareResultStatus.success:
          default:
            break;
        }
        dir.deleteSync(recursive: true);
      });
    });
  }

  /// [apiSave] saves the record to https://flutster.com API
  Future<String> apiSave({
    List<FlutsterTestEvent>? runEvents,
    bool? runResult,
    int retries = 20,
  }) async {
    if (apiKey == null ||
        apiUser == null ||
        apiUrl == null ||
        apiKey!.isEmpty ||
        apiUser!.isEmpty ||
        apiUrl!.isEmpty) {
      return ("API save is only possible if apiKey, apiUser and apiUrl are "
          "provided");
    }
    String? ret;
    Map<String, String> headers = {
      "v": apiVersion,
    };
    Map<String, String> data = {
      "api": "tr",
    };
    bool create = false;
    if (id == null) {
      if (runEvents != null) {
        return ("Cannot save run events without a test record id");
      }
      create = true;
      data["tr"] = "createContent";
    } else {
      if (runEvents != null) {
        if (runResult == null) {
          return ("Cannot save run without run result");
        }
        data["tr"] = "createRun";
        data["runResult"] = runResult ? "1" : "0";
      } else {
        data["tr"] = "updateContent";
      }
      data["trid"] = id.toString();
    }
    data["u"] = apiUser!;
    data["ak"] = apiKey!;
    data["content"] = toJson(alternateEvents: runEvents);
    String? res = await send(
      apiUrl!,
      data,
      headers: headers,
      timeoutMS: 10000,
    );
    bool wentOk =
        (res?.startsWith("ok") ?? false) || (res?.startsWith("soso") ?? false);
    if (res == null || !wentOk) {
      ret = apiCallResultToMessage(res, "Error saving record to API");
    } else {
      if (create || runResult != null) {
        int? resId = int.tryParse(res.replaceRange(0, 3, ""));
        if (resId == null) {
          ret = "Bad record id from API";
        } else {
          if (runResult == null) {
            id = resId;
          } else {
            debugPrint("Run id: $resId");
            return ("Record saved to API");
          }
        }
      }
    }
    if (wentOk) {
      return ("Record saved to API");
    }
    if (retries > 0) {
      debugPrint("Warning: retrying to save to API: $retries");
      return (await apiSave(
        runEvents: runEvents,
        runResult: runResult,
        retries: retries - 1,
      ));
    }
    return (ret ?? "Failed to save record to API");
  }

  /// [apiDelete] deletes the record from the https://flutster.com API.
  Future<String> apiDelete() async {
    if (apiKey == null ||
        apiUser == null ||
        apiUrl == null ||
        apiKey!.isEmpty ||
        apiUser!.isEmpty ||
        apiUrl!.isEmpty) {
      return ("API delete is only possible if apiKey, apiUser and apiUrl are "
          "provided");
    }
    if (id == null) {
      return ("API delete is only possible with a test record id");
    }
    Map<String, String> headers = {
      "v": apiVersion,
    };
    Map<String, String> data = {
      "api": "tr",
    };
    data["tr"] = "delete";
    data["trid"] = id.toString();
    data["u"] = apiUser!;
    data["ak"] = apiKey!;
    String? res = await send(
      apiUrl!,
      data,
      headers: headers,
      timeoutMS: 10000,
    );
    if (res == null || (!res.startsWith("ok") && !res.startsWith("soso"))) {
      return (apiCallResultToMessage(res, "Error on API test record delete"));
    }
    return ("Test record deleted from API");
  }

  /// [send] Function used to send the data to the server.
  /// This is for post method.
  /// Returns the response body as a String in case of success and null
  /// otherwise.
  /// [urlWithoutParameters] The matomo.php URL without the parameters.
  /// [data] The parameters to be sent by post.
  /// [headers] The headers to be sent along with request.
  static Future<String?> send(
    String urlWithoutParameters,
    Object data, {
    Map<String, String>? headers,
    int timeoutMS = 10000,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(urlWithoutParameters),
            body: data,
            headers: headers,
          )
          .timeout(Duration(
            milliseconds: timeoutMS,
          ));
      if (res.statusCode.toString()[0] != "2") {
        if (res.body.startsWith("{\"error\":")) {
          return (res.body);
        }
        return ('{"error":"code ${res.statusCode}",'
            '"message":'
            '"${res.body.replaceAll('"', "'").replaceAll("\n", "")}"}');
      }
      return (res.body);
    } catch (e, st) {
      debugPrint("$e $st");
      return (null);
    }
  }

  /// [playToApi] plays the record events and saves the run to the
  /// https://flutster.com API.
  /// Returns true in case the run succeeded.
  /// assertion to check whether test run was saved.
  Future<bool> playToApi(WidgetTester tester) async {
    List<FlutsterTestEvent> results = [];
    bool ret = await play(tester, results: results);
    String res = await apiSave(runEvents: results, runResult: ret);
    assert(res == "Record saved to API",
        "Error: Run results not saved to API: $res");
    return (ret);
  }

  /// [play] runs the events and returns true in case all passed.
  Future<bool> play(WidgetTester tester,
      {List<FlutsterTestEvent>? results}) async {
    bool ret = true;
    if (events.isEmpty) {
      debugPrint("Warning: no test events while playing!");
      return (false);
    }
    // combineAll();
    for (FlutsterTestEvent event in events) {
      bool result = await event.play(tester: tester, results: results);
      if (expect != null) {
        expect!(
          result,
          true,
          reason: "Event play: ${event.strSummary()}",
        );
      }
      if (!result) {
        ret = false;
      }
      if (event.type != FlutsterTestEventType.key) {
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpAndSettle();
    return (ret);
  }

  /// [combineAll] calls the first event combineAll method that will shrink
  /// the events list when possible. In particular, the keyboard events are
  /// combined to form words.
  void combineAll() {
    events.first.combineAll();
  }

  /// [containsScreenShot] returns true if at least one of the events is a
  /// screenshot.
  bool containsScreenShot() {
    return (events
        .any((element) => element.type == FlutsterTestEventType.screenShot));
  }

  /// [apiListing] returns the list of records from https://flutster.com API as
  /// a json string.
  Future<String> apiListing() async {
    if (apiKey == null ||
        apiUser == null ||
        apiUrl == null ||
        apiKey!.isEmpty ||
        apiUser!.isEmpty ||
        apiUrl!.isEmpty) {
      return ("API listing is only possible if apiKey, apiUser and apiUrl are "
          "provided");
    }
    Map<String, String> headers = {
      "v": apiVersion,
    };
    Map<String, String> data = {
      "api": "tr",
    };
    data["tr"] = "list";
    data["u"] = apiUser!;
    data["ak"] = apiKey!;
    String? res = await send(
      apiUrl!,
      data,
      headers: headers,
      timeoutMS: 10000,
    );
    if (res == null) {
      return (apiCallResultToMessage(res, "Error listing records from API"));
    }
    return (res);
  }

  /// [apiCallResultToMessage] eases the treatment of https://flutster.com API
  /// call errors.
  String apiCallResultToMessage(String? res, String message) {
    if (res?.startsWith("{\"error\":") ?? false) {
      Map<String, dynamic> error = jsonDecode(res!);
      message += "\nAPI error type: ";
      message += error["error"]!;
      if (error.containsKey("message")) {
        message += "\nMessage from API: ";
        message += error["message"]!;
      }
      switch (error["error"]) {
        case "plan restriction":
          message += "\nConsider upgrading your API plan.";
          break;
        default:
          break;
      }
    }
    return (message);
  }
}

/// [FlutsterTestEventType] is an enum for all the Flutster test event types.
enum FlutsterTestEventType {
  /// [key] corresponds to a keyboard key event.
  key,

  /// [tap] corresponds to a mouse click event.
  tap,

  /// [screenShot] corresponds to a validation screenshot event.
  screenShot,

  /// [none] means that the type is undefined.
  none,
}

/// [FlutsterTestEvent] is a Flutster test step.
class FlutsterTestEvent {
  /// [resultMessage] is the output Widget of the test event run.
  Widget? resultMessage;

  /// [pixelMatchingToleranceEditKey] can be used to retrieve the tolerance
  /// value.
  Key pixelMatchingToleranceEditKey =
      const Key("pixelMatchingToleranceEditKey");

  /// [iMEDSigmaEditKey] can be used to retrieve the sigma value.
  Key iMEDSigmaEditKey = const Key("IMEDSigmaEditKey");

  /// [iMEDBlurRatioEditKey] can be used to retrieve the ratio value.
  Key iMEDBlurRatioEditKey = const Key("IMEDBlurRatioEditKey");

  /// [keyEventDown] is true for key press and false for key release.
  bool? keyEventDown;

  /// [keyLabel] value of logicalKey.keyLabel of a [KeyEvent].
  String? keyLabel;

  /// [type] holds the type of the event.
  FlutsterTestEventType type = FlutsterTestEventType.key;

  /// [time] is the time at which the event occurred.
  DateTime time = DateTime.fromMillisecondsSinceEpoch(0);

  /// [resumeTime] is the time at which the recording resumed.
  DateTime? resumeTime;

  /// [typedText] for a key event is the equivalent typed text if any.
  String? typedText;

  /// [keyEvent] is the originating key event available while recording.
  KeyEvent? keyEvent;

  /// [tapStart] is the position of the tap start.
  Offset? tapStart;

  /// [tapStart] is the position of the tap stop.
  Offset? tapStop;

  /// [tapDuration] is the duration of the tap.
  Duration? tapDuration;

  /// [waitDuration] is the duration to wait before starting the event play.
  Duration? waitDuration;

  /// [screenShot] is the Image of the screenshot.
  Image? screenShot;

  /// [screenShotBytes] holds the bytes of the screenshot image.
  Uint8List? screenShotBytes;

  /// [context] used while displaying the Flutster test recording menu.
  BuildContext? context;

  /// [editTypedTextController] allows to set the typed text for a key event in
  /// the context of the Flutster test recording menu.
  TextEditingController editTypedTextController = TextEditingController();

  /// [screenShotAcceptancePctThreshold] is the minimum percentage of picture
  /// matching to consider that two screenshots are identical.
  double screenShotAcceptancePctThreshold = 99.999;

  /// [pixelMatchingTolerance] is necessary when using the pixel matching image
  /// comparison method. The smaller the stricter.
  double pixelMatchingTolerance = 0.02;

  /// [iMEDSigma] is used for the IMED image comparison method.
  double iMEDSigma = 1;

  /// [iMEDBlurRatio] is used for the IMED image comparison method.
  double iMEDBlurRatio = 0.005;

  /// [screenShotMatchResult] holds the result of the screenshot image
  /// comparison.
  double? screenShotMatchResult;

  /// [screenShotComparisonFunctions] holds the image comparison functions
  /// used for the validation screenshots. More information here:
  /// https://pub.dev/packages/image_compare
  Map<String, Function> screenShotComparisonFunctions = {
    "Pixel - Matching": (dynamic image1, dynamic image2, pixelMatchingTolerance,
        iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1,
          src2: image2,
          algorithm: PixelMatching(
              ignoreAlpha: true, tolerance: pixelMatchingTolerance)));
    },
    "Pixel - Euclidean Color Distance": (dynamic image1, dynamic image2,
        pixelMatchingTolerance, iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1,
          src2: image2,
          algorithm: EuclideanColorDistance(
            ignoreAlpha: true,
          )));
    },
    "Pixel - IMED": (dynamic image1, dynamic image2, pixelMatchingTolerance,
        iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1,
          src2: image2,
          algorithm: IMED(sigma: iMEDSigma, blurRatio: iMEDBlurRatio)));
    },
    "Histogram - Chi Square Distance": (dynamic image1, dynamic image2,
        pixelMatchingTolerance, iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1,
          src2: image2,
          algorithm: ChiSquareDistanceHistogram(
            ignoreAlpha: true,
          )));
    },
    "Histogram - Intersection": (dynamic image1, dynamic image2,
        pixelMatchingTolerance, iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1,
          src2: image2,
          algorithm: IntersectionHistogram(
            ignoreAlpha: true,
          )));
    },
    "Hash - Perceptual": (dynamic image1, dynamic image2,
        pixelMatchingTolerance, iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1, src2: image2, algorithm: PerceptualHash()));
    },
    "Hash - Average": (dynamic image1, dynamic image2, pixelMatchingTolerance,
        iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1, src2: image2, algorithm: AverageHash()));
    },
    "Hash - Median": (dynamic image1, dynamic image2, pixelMatchingTolerance,
        iMEDSigma, iMEDBlurRatio) {
      return (compareImages(
          src1: image1, src2: image2, algorithm: MedianHash()));
    },
  };

  /// [screenShotComparisonFunctionName] as held in
  /// [screenShotComparisonFunctions].
  String? screenShotComparisonFunctionName;

  /// [defaultScreenshotComparisonFunctionName] is the default name of the image
  /// comparison function as held in [defaultScreenshotComparisonFunctionName]
  static const String defaultScreenshotComparisonFunctionName =
      "Pixel - Matching";

  /// [flutsterTestRecorderState] if given is returned as the current
  /// [FlutsterTestRecorderState] by [recorderState].
  FlutsterTestRecorderState? flutsterTestRecorderState;

  /// [tester] is provided by the integration testing to conduct the testing.
  WidgetTester? tester;

  /// [widgetName] is used by [recorderState] to find the right
  /// [FlutsterTestRecorderState] while testing.
  String? widgetName;

  /// [getRecord] returns the [FlutsterTestRecord] holding this event.
  Future<FlutsterTestRecord?> getRecord() async {
    return ((await recorderState())?.widget.flutsterTestRecord);
  }

  /// Constructor used by the named factories.
  FlutsterTestEvent._({
    required this.type,
    DateTime? time,
    this.typedText,
    this.keyEvent,
    this.tapStart,
    this.tapStop,
    this.tapDuration,
    this.screenShot,
    this.screenShotBytes,
    this.flutsterTestRecorderState,
    this.tester,
    this.widgetName,
  }) {
    this.time = time ?? DateTime.now();
  }

  /// [screenShot] factory is used to create a validating screenshot test event.
  factory FlutsterTestEvent.screenShot({
    DateTime? time,
    required Image screenShot,
    required Uint8List screenShotBytes,
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
    String? widgetName,
  }) =>
      FlutsterTestEvent._(
        flutsterTestRecorderState: flutsterTestRecorderState,
        tester: tester,
        time: time,
        type: FlutsterTestEventType.screenShot,
        screenShot: screenShot,
        screenShotBytes: screenShotBytes,
        widgetName: widgetName,
      );

  /// [text] factory is used to create key test event.
  factory FlutsterTestEvent.text({
    DateTime? time,
    required String typedText,
    required KeyEvent? keyEvent,
    String? keyLabel,
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
    String? widgetName,
  }) {
    FlutsterTestEvent ret = FlutsterTestEvent._(
      flutsterTestRecorderState: flutsterTestRecorderState,
      tester: tester,
      time: time,
      type: FlutsterTestEventType.key,
      typedText: typedText,
      keyEvent: keyEvent,
      widgetName: widgetName,
    );
    if (keyEvent is KeyUpEvent || keyEvent is RawKeyUpEvent) {
      ret.keyEventDown = false;
    } else if (keyEvent is KeyDownEvent || keyEvent is RawKeyDownEvent) {
      ret.keyEventDown = true;
    }
    if (keyLabel != null) {
      ret.keyLabel = keyLabel;
    } else {
      ret.keyLabel = keyEventKeyLabelStatic(keyEvent);
    }
    return (ret);
  }

  /// [tap] factory is used to create a tap test event.
  factory FlutsterTestEvent.tap({
    DateTime? time,
    required Offset tapStart,
    Offset? tapStop,
    Duration tapDuration = const Duration(milliseconds: 0),
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
    String? widgetName,
  }) =>
      FlutsterTestEvent._(
        flutsterTestRecorderState: flutsterTestRecorderState,
        tester: tester,
        time: time,
        type: FlutsterTestEventType.tap,
        tapStart: tapStart,
        tapStop: tapStop,
        tapDuration: tapDuration,
        widgetName: widgetName,
      );

  /// [recorderState] returns the [FlutsterTestRecorderState] displayed on the
  /// testing screen.
  Future<FlutsterTestRecorderState?> recorderState({int retries = 10}) async {
    if (flutsterTestRecorderState != null) {
      return (flutsterTestRecorderState!);
    }
    assert(
        tester != null,
        "Error: flutsterTestRecorderState and tester are null, nothing to get"
        " the state.");
    bool gotANewState = false;
    FlutsterTestRecorder? recorder;
    for (int i = 0; i < 10; i++) {
      FlutsterTestRecorderState? holdingState;
      try {
        recorder = tester!.allWidgets.firstWhere((element) {
          if (element is! FlutsterTestRecorder) {
            return (false);
          }
          if (widgetName == null) {
            return (true);
          }
          bool widgetNameMatches = element.name == widgetName;
          return (widgetNameMatches);
        }) as FlutsterTestRecorder?;
        holdingState = recorder?.stateKeeper.state;
        if (holdingState != null) {
          latestState = holdingState;
          gotANewState = true;
          break;
        } else {
          debugPrint("Warning: got a null holdingState while recorder.name:"
              " ${recorder?.name}");
        }
      } catch (e, st) {
        debugPrint("Warning: failed to get the state: ${e.toString()} "
            "${st.toString()}");
      }
    }
    if (!gotANewState) {
      if (retries > 0) {
        await tester?.pumpAndSettle();
        debugPrint(
            "Warning: didn't get a new state corresponding to the widgetName: "
            "${widgetName ?? "null"} retrying up to $retries times. Got "
            "${tester!.allWidgets.length} to choose from.");
        await Future.delayed(const Duration(milliseconds: 300));
        return (recorderState(retries: retries - 1));
      } else {
        debugPrint("Warning: exhausted retries trying to get the new state for "
            "widgetName: ${widgetName ?? "null"}");
      }
    }
    return (latestState);
  }

  /// [keyEventKeyLabelStatic] returns the String that can be used to represent
  /// the given event in a UI.
  static String? keyEventKeyLabelStatic(KeyEvent? keyEvent) {
    String? ret;
    try {
      ret = keyEvent?.logicalKey.keyLabel;
    } catch (e) {
      debugPrint("Warning: failed to get keyEventKeyLabelStatic");
    }
    return (ret);
  }

  /// [keyEventKeyLabel] is the non static version of the
  /// [keyEventKeyLabelStatic] function.
  String? get keyEventKeyLabel {
    return (keyEventKeyLabelStatic(keyEvent));
  }

  /// [tapUp] records the end of a tap.
  tapUp(Offset tapStop, {Duration? tapDuration, DateTime? time}) {
    assert(tapDuration == null || time == null,
        "At least one of tapDuration or time must be null.");
    if (type != FlutsterTestEventType.tap) {
      throw Exception("Trying to up a tap on a non tap event.");
    }
    this.tapStop = tapStop;
    if (tapDuration != null) {
      this.tapDuration = tapDuration;
    }
    if (time != null) {
      this.tapDuration = time.difference(this.time);
    }
    this.tapDuration ??= DateTime.now().difference(this.time);
  }

  /// [build] returns the widget that can be used to represent the event in a
  /// UI.
  Widget build(StateSetter setState, List<FlutsterTestEvent> events,
      BuildContext context) {
    this.context = context;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white60,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 2,
          color: Colors.grey,
        ),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildIcon(),
                Text(waitDuration?.toStringYouHave() ?? ""),
                FutureBuilder(
                  future: canBeCombined(),
                  builder: (BuildContext fContext, AsyncSnapshot snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        !snapshot.hasError &&
                        snapshot.hasData &&
                        snapshot.data) {
                      return (IconButton(
                        icon: const Icon(
                          Icons.auto_awesome_motion,
                          color: Colors.blue,
                          semanticLabel: "Combine",
                        ),
                        onPressed: () {
                          combine(setState);
                          setState(() {});
                        },
                      ));
                    }
                    return (const SizedBox.shrink());
                  },
                ),
                playButton(
                  setState,
                ),
                IconButton(
                  onPressed: () {
                    edit(setState);
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.blue,
                    semanticLabel: "Edit",
                  ),
                ),
                IconButton(
                  onPressed: () {
                    delete();
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    semanticLabel: "Delete",
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Text("Widget name: ${widgetName ?? "null"}"),
              ])),
          buildPreview(),
        ],
      ),
    );
  }

  /// [screenShotToB64] returns the screenshot image bytes in base 64.
  String screenShotToB64() {
    return base64Encode(screenShotBytes!);
  }

  /// [buildIcon] returns the icon icon widget that best represents the event.
  Widget buildIcon() {
    return Icon(
      type == FlutsterTestEventType.screenShot
          ? Icons.camera
          : type == FlutsterTestEventType.tap
              ? Icons.mouse
              : type == FlutsterTestEventType.key
                  ? Icons.text_fields
                  : Icons.error,
    );
  }

  /// [presentImage] returns a widget to display the given [image] in a UI.
  Widget presentImage(Widget image) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: 2,
          color: Colors.black,
        ),
      ),
      child: image,
    );
  }

  /// [buildPreview] returns the widget to display to preview the event.
  Widget buildPreview() {
    if (type == FlutsterTestEventType.screenShot) {
      return presentImage(
          screenShot ?? const Icon(Icons.error, color: Colors.red));
    }
    if (type == FlutsterTestEventType.tap) {
      return (Text(tapSummaryStr()));
    }
    if (type == FlutsterTestEventType.key) {
      String ret = "empty";
      if ((typedText?.isNotEmpty ?? false)) {
        ret = "'${typedText!}'";
      } else if (characterCharacter().isNotEmpty && isCharacterAZ()) {
        ret = "'${characterCharacter()}'";
      } else if (keyLabel?.isNotEmpty ?? false) {
        ret = keyLabel!;
      }
      IconData icon = keyEventDown == null
          ? Icons.repeat
          : keyEventDown!
              ? Icons.arrow_circle_down
              : Icons.arrow_circle_up;
      return (Wrap(children: [Text(ret), Icon(icon)]));
    }
    return (const Text("No preview"));
  }

  /// [canBeCombined] returns true in case the event can be combined. This is
  /// often the case for key events that have never been combined.
  Future<bool> canBeCombined() async {
    if (type != FlutsterTestEventType.key) {
      return (false);
    }
    FlutsterTestEvent? previous = (await getRecord())?.findPreviousEvent(this);
    FlutsterTestEvent? next = (await getRecord())?.findNextEvent(this);
    if (previous == null && next == null) {
      return (false);
    }
    if ((previous?.type ?? FlutsterTestEventType.none) ==
        FlutsterTestEventType.key) {
      return (true);
    }
    if ((next?.type ?? FlutsterTestEventType.none) ==
        FlutsterTestEventType.key) {
      return (true);
    }
    return (false);
  }

  /// [combine] is called to combine the event with others. In effect, it will
  /// combine all events in the record that can be combined.
  combine(StateSetter updateParent) async {
    (await getRecord())?.combineAll();
    updateParent(() {});
  }

  /// [delete] deletes the event from the record.
  delete() async {
    (await getRecord())?.deleteEvent(this);
  }

  /// [edit] displays a dialog fro which the event can be edited.
  void edit(StateSetter updateParent) {
    showDialog(
        context: context!,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (editDialogContext, StateSetter setState) {
            return (AlertDialog(
              title: const Text("Edit test event"),
              content: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Column(
                    children: buildEditWidgets(updateParent, setState),
                  ),
                ),
              ),
              actions: [
                playButton(
                  setState,
                  editDialogContext: editDialogContext,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(editDialogContext).pop();
                  },
                ),
              ],
            ));
          });
        });
  }

  /// [buildEditWidgets] builds the edit widget as the content to the dialog
  /// displayed by [edit].
  List<Widget> buildEditWidgets(
      StateSetter updateParent, StateSetter setState) {
    List<Widget> ret = [];
    ret.add(resultMessage == null ? const SizedBox.shrink() : resultMessage!);
    ret.add(TextFormField(
      autovalidateMode: AutovalidateMode.always,
      initialValue: waitDuration!.inMilliseconds.toString(),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: false,
        signed: false,
      ),
      decoration: const InputDecoration(
        labelText: "Milliseconds to wait before execution",
      ),
      validator: FlutsterTestRecord.uIntValidator,
      onChanged: (milliseconds) {
        if (FlutsterTestRecord.uIntValidator(milliseconds) == null) {
          waitDuration =
              Duration(milliseconds: int.tryParse(milliseconds) ?? 0);
        }
        updateParent(() {});
      },
    ));
    ret.add(TextFormField(
      autovalidateMode: AutovalidateMode.always,
      initialValue: widgetName ?? "",
      keyboardType: TextInputType.name,
      decoration: const InputDecoration(
        labelText: "Widget name",
      ),
      validator: FlutsterTestRecord.testNameValidator,
      onChanged: (wName) {
        if (FlutsterTestRecord.testNameValidator(wName) == null) {
          widgetName = wName;
        }
        updateParent(() {});
      },
    ));
    if (type == FlutsterTestEventType.key) {
      editTypedTextController.text = typedText ?? "";
      ret.add(TextFormField(
        controller: editTypedTextController,
        decoration: const InputDecoration(
          labelText: "Entered text",
        ),
        onChanged: (text) {
          typedText = text;
          keyEvent = null;
          updateParent(() {});
        },
      ));
      ret.add(const Center(child: Text("or backspace:")));
      ret.add(IconButton(
        icon: const Icon(
          Icons.backspace,
          color: Colors.blue,
        ),
        onPressed: () {
          typedText = "";
          editTypedTextController.text = "";
          keyEvent = const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.backspace,
            logicalKey: LogicalKeyboardKey.backspace,
            timeStamp: Duration(milliseconds: 1),
          );
          updateParent(() {});
          setState(() {});
        },
      ));
    }
    if (type == FlutsterTestEventType.tap) {
      ret.add(TextFormField(
        autovalidateMode: AutovalidateMode.always,
        initialValue: tapStart!.dx.round().toString(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        decoration: const InputDecoration(
          labelText: "Tap start x",
        ),
        validator: FlutsterTestRecord.uIntValidator,
        onChanged: (uInt) {
          if (FlutsterTestRecord.uIntValidator(uInt) == null) {
            tapStart = Offset(double.tryParse(uInt) ?? 0, tapStart!.dy);
          }
          updateParent(() {});
        },
      ));
      ret.add(TextFormField(
        autovalidateMode: AutovalidateMode.always,
        initialValue: tapStart!.dy.round().toString(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        decoration: const InputDecoration(
          labelText: "Tap start y",
        ),
        validator: FlutsterTestRecord.uIntValidator,
        onChanged: (uInt) {
          if (FlutsterTestRecord.uIntValidator(uInt) == null) {
            tapStart = Offset(
              tapStart!.dx,
              double.tryParse(uInt) ?? 0,
            );
          }
          updateParent(() {});
        },
      ));
      ret.add(TextFormField(
        autovalidateMode: AutovalidateMode.always,
        initialValue: tapDuration!.inMilliseconds.toString(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        decoration: const InputDecoration(
          labelText: "Tap duration in milliseconds",
        ),
        validator: FlutsterTestRecord.uIntValidator,
        onChanged: (uInt) {
          if (FlutsterTestRecord.uIntValidator(uInt) == null) {
            tapDuration = Duration(milliseconds: int.tryParse(uInt) ?? 0);
          }
          updateParent(() {});
        },
      ));
      ret.add(TextFormField(
        autovalidateMode: AutovalidateMode.always,
        initialValue: tapStop!.dx.round().toString(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        decoration: const InputDecoration(
          labelText: "Tap end x",
        ),
        validator: FlutsterTestRecord.uIntValidator,
        onChanged: (uInt) {
          if (FlutsterTestRecord.uIntValidator(uInt) == null) {
            tapStop = Offset(double.tryParse(uInt) ?? 0, tapStop!.dy);
          }
          updateParent(() {});
        },
      ));
      ret.add(TextFormField(
        autovalidateMode: AutovalidateMode.always,
        initialValue: tapStop!.dy.round().toString(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: false,
          signed: false,
        ),
        decoration: const InputDecoration(
          labelText: "Tap end y",
        ),
        validator: FlutsterTestRecord.uIntValidator,
        onChanged: (uInt) {
          if (FlutsterTestRecord.uIntValidator(uInt) == null) {
            tapStop = Offset(
              tapStop!.dx,
              double.tryParse(uInt) ?? 0,
            );
          }
          updateParent(() {});
        },
      ));
    }
    if (type == FlutsterTestEventType.screenShot) {
      ret.add(TextFormField(
        autovalidateMode: AutovalidateMode.always,
        initialValue: screenShotAcceptancePctThreshold.toString(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: false,
        ),
        decoration: const InputDecoration(
          labelText: "Match percentage threshold",
        ),
        validator: FlutsterTestRecord.pctValidator,
        onChanged: (doubleString) {
          if (FlutsterTestRecord.pctValidator(doubleString) == null) {
            screenShotAcceptancePctThreshold =
                double.tryParse(doubleString) ?? 99.999;
          }
          updateParent(() {});
        },
      ));
      ret.add(presentImage(
          screenShot ?? const Icon(Icons.error, color: Colors.red)));
      ret.add(const Text("Select image matching algorithm:"));
      ret.add(DropdownButtonFormField(
        items: screenShotComparisonFunctions.keys
            .toList()
            .map<DropdownMenuItem<String>>(
                (algorithmName) => DropdownMenuItem<String>(
                      value: algorithmName,
                      child: Text(algorithmName),
                    ))
            .toList(),
        onChanged: (String? algorithmName) {
          screenShotComparisonFunctionName =
              algorithmName ?? defaultScreenshotComparisonFunctionName;
          setState(() {});
        },
        value: screenShotComparisonFunctionName ??
            defaultScreenshotComparisonFunctionName,
      ));
      if (screenShotComparisonFunctionName == "Pixel - Matching") {
        ret.add(TextFormField(
          key: pixelMatchingToleranceEditKey,
          autovalidateMode: AutovalidateMode.always,
          initialValue: pixelMatchingTolerance.toString(),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          decoration: const InputDecoration(
            labelText: "Pixel matching tolerance",
          ),
          validator: FlutsterTestRecord.ratioValidator,
          onChanged: (doubleString) {
            if (screenShotComparisonFunctionName == "Pixel - Matching") {
              if (FlutsterTestRecord.ratioValidator(doubleString) == null) {
                pixelMatchingTolerance = double.tryParse(doubleString) ?? 0.02;
              }
              updateParent(() {});
            }
          },
        ));
      }
      if (screenShotComparisonFunctionName == "Pixel - IMED") {
        ret.add(TextFormField(
          key: iMEDSigmaEditKey,
          autovalidateMode: AutovalidateMode.always,
          initialValue: iMEDSigma.toString(),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          decoration: const InputDecoration(
            labelText: "IMED sigma",
          ),
          validator: FlutsterTestRecord.uDoubleValidator,
          onChanged: (doubleString) {
            if (screenShotComparisonFunctionName == "Pixel - IMED") {
              if (FlutsterTestRecord.uDoubleValidator(doubleString) == null) {
                iMEDSigma = double.tryParse(doubleString) ?? 1;
              }
              updateParent(() {});
            }
          },
        ));
        ret.add(TextFormField(
          key: iMEDBlurRatioEditKey,
          autovalidateMode: AutovalidateMode.always,
          initialValue: iMEDBlurRatio.toString(),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          decoration: const InputDecoration(
            labelText: "IMED blur ratio",
          ),
          validator: FlutsterTestRecord.ratioValidator,
          onChanged: (doubleString) {
            if (screenShotComparisonFunctionName == "Pixel - IMED") {
              if (FlutsterTestRecord.ratioValidator(doubleString) == null) {
                iMEDBlurRatio = double.tryParse(doubleString) ?? 0.005;
              }
              updateParent(() {});
            }
          },
        ));
      }
    }
    return (ret);
  }

  /// [compareTwoImages] returns the output of the screenshot comparison
  /// function.
  /// Number between 0 and 1.
  /// Closer to 0 means very similar images.
  /// Closer to 1 means very different images.
  Future<double> compareTwoImages(
    Uint8List image1,
    Uint8List image2,
    double pixelMatchingTolerance,
    double iMEDSigma,
    double iMEDBlurRatio, {
    bool reverse = false,
  }) async {
    try {
      return (await screenShotComparisonFunctions[
          screenShotComparisonFunctionName ??
              defaultScreenshotComparisonFunctionName]!(
        image1,
        image2,
        pixelMatchingTolerance,
        iMEDSigma,
        iMEDBlurRatio,
      ));
    } catch (e, st) {
      if (!reverse) {
        return (await compareTwoImages(
          image2,
          image1,
          pixelMatchingTolerance,
          iMEDSigma,
          iMEDBlurRatio,
          reverse: true,
        ));
      }
      debugPrint("Failed to compare images: ${e.toString()} ${st.toString()}");
      return (1);
    }
  }

  /// [screenShotComparison] returns true if the given screenshot matches the
  /// event screenshot.
  Future<bool> screenShotComparison(Uint8List newScreenShotBytes) async {
    Uint8List previousBytes = screenShotBytes!;
    Uint8List nextBytes = newScreenShotBytes;
    Uint8List image1, image2;
    if (previousBytes.length > nextBytes.length) {
      //In some cases, if the first images is smaller than the second image, the
      // comparison throws an exception.
      image1 = nextBytes;
      image2 = previousBytes;
    } else {
      image2 = nextBytes;
      image1 = previousBytes;
    }
    double screenshotComparisonResult = 1;
    screenshotComparisonResult = await compareTwoImages(
      image1,
      image2,
      pixelMatchingTolerance,
      iMEDSigma,
      iMEDBlurRatio,
    );
    screenShotMatchResult = 100.0 * screenshotComparisonResult;
    return (100.0 - screenShotMatchResult! >= screenShotAcceptancePctThreshold);
  }

  /// [play] runs the event if possible and returns false if there was a
  /// failure.
  Future<bool> play({
    WidgetTester? tester,
    List<FlutsterTestEvent>? results,
  }) async {
    bool ret = false;
    FlutsterTestEvent? result;
    switch (type) {
      case FlutsterTestEventType.screenShot:
        result = await (await recorderState())?.playEvent(
          this,
          tester: tester,
          delay: waitDuration ?? const Duration(milliseconds: 0),
        );
        resultMessage = await eventReplayComparisonResultString(result);
        if (resultMessage is Wrap) {
          resultMessage = (resultMessage as Wrap)
              .children
              .firstWhere((element) => element is Text);
        }
        ret = resultMessage is Text &&
            (((resultMessage as Text).data) ?? "") == "Screenshots match";
        break;
      case FlutsterTestEventType.tap:
        result = await (await recorderState())?.playEvent(
          this,
          tester: tester,
          delay: waitDuration ?? const Duration(milliseconds: 0),
        );
        ret = result == this;
        break;
      case FlutsterTestEventType.key:
        if (tester == null) {
          debugPrint(
              "playing a key event without a WidgetTester (not while running a "
              "test in other words), is not supported");
          ret = false;
        }
        result = await (await recorderState())?.playEvent(
          this,
          tester: tester,
          delay: waitDuration ?? const Duration(milliseconds: 0),
        );
        ret = result == this;
        break;
      default:
        assert(false, "Unknown FlutsterTestEventType in play");
        ret = false;
        break;
    }
    if (results != null && result != null) {
      results.add(result);
    }
    return (ret);
  }

  /// [playButton] returns the widget to display a play button to run the event.
  Widget playButton(StateSetter setState, {BuildContext? editDialogContext}) {
    if (type == FlutsterTestEventType.key) {
      return (const SizedBox
          .shrink()); //Replaying KeyEvents in non web and non test run is not
      // possible.
    }
    void Function() tryToPopEditDialog;
    tryToPopEditDialog = () {
      if (editDialogContext != null) {
        Navigator.of(editDialogContext).pop();
      }
    };
    return (IconButton(
      icon: const Icon(Icons.play_arrow, color: Colors.lightGreenAccent),
      onPressed: () async {
        if (type == FlutsterTestEventType.screenShot) {
          setState(() {
            resultMessage = const CircularProgressIndicator();
          });
        }
        if (type == FlutsterTestEventType.tap ||
            type == FlutsterTestEventType.key) {
          (await recorderState())
              ?.playEvent(this, delay: const Duration(milliseconds: 2000));
          Future.delayed(const Duration(milliseconds: 500)).whenComplete(() {
            Navigator.of(context!).pop();
          });
          tryToPopEditDialog();
        } else if (type == FlutsterTestEventType.screenShot) {
          resultMessage = await eventReplayComparisonResultString(
              await (await recorderState())?.playEvent(
            this,
          ));
          setState(() {});
        } else {
          resultMessage = const Text("Unknown test type!");
          setState(() {});
        }
      },
    ));
  }

  /// [eventReplayComparisonResultString] returns a Text widget with the result
  /// of the result of the event run.
  Future<Widget> eventReplayComparisonResultString(
      FlutsterTestEvent? playEvent) async {
    if (playEvent == null) {
      return (const Text("Event failed to play"));
    }
    if (playEvent.type != type) {
      return (const Text("Event is of wrong type"));
    }
    if (type == FlutsterTestEventType.screenShot) {
      if (playEvent.screenShot == null) {
        return (const Text("Replay has an empty screenshot"));
      }
      bool res = await screenShotComparison(playEvent.screenShotBytes!);
      playEvent.screenShotMatchResult = screenShotMatchResult;
      if (res) {
        return Wrap(
          children: [
            const Text("Screenshots match"),
            presentImage(playEvent.screenShot!),
          ],
        );
      }
      return Wrap(
        children: [
          const Text("Screenshots don't match"),
          presentImage(playEvent.screenShot!),
        ],
      );
    }
    return (const Text("eventReplayComparisonResultString not implemented"));
  }

  /// [toMap] returns the event as a map.
  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {
      "type": type.toString().split(".").last,
      "waitDuration": waitDuration?.inMilliseconds,
      "time": time.millisecondsSinceEpoch,
      "widgetName": widgetName,
    };
    switch (type) {
      case FlutsterTestEventType.key:
        ret["logicalKey.keyId"] = keyEvent?.logicalKey.keyId;
        ret["physicalKey.usbHidUsage"] = keyEvent?.physicalKey.usbHidUsage;
        ret["keyEvent.duration"] = keyEvent?.timeStamp.inMilliseconds;
        ret["typedText"] = ifJsonAble(typedText) ?? "";
        ret["keyEventDown"] = keyEventDown;
        ret["character"] = ifJsonAble(keyEvent?.character) ?? "";
        ret["logicalKey.keyLabel"] = keyEventKeyLabel;
        break;
      case FlutsterTestEventType.tap:
        ret["tapStart.dx"] = tapStart?.dx;
        ret["tapStart.dy"] = tapStart?.dy;
        ret["tapDuration"] = tapDuration?.inMilliseconds;
        ret["tapStop.dx"] = tapStop?.dx;
        ret["tapStop.dy"] = tapStop?.dy;
        break;
      case FlutsterTestEventType.screenShot:
        ret["screenShot"] = screenShotBytes == null ? null : screenShotToB64();
        ret["screenShotComparisonFunctionName"] =
            screenShotComparisonFunctionName ??
                defaultScreenshotComparisonFunctionName;
        ret["screenShotAcceptancePctThreshold"] =
            screenShotAcceptancePctThreshold;
        ret["pixelMatchingTolerance"] = pixelMatchingTolerance;
        ret["IMEDBlurRatio"] = iMEDBlurRatio;
        ret["IMEDSigma"] = iMEDSigma;
        if (screenShotMatchResult != null) {
          ret["screenShotMatchResult"] = screenShotMatchResult;
        }
        break;
      default:
        assert(false, "Unknown FlutsterTestEventType in toMap");
        break;
    }
    return (ret);
  }

  /// [fromMap] factory returns an event build from a map.
  factory FlutsterTestEvent.fromMap(
    Map<String, dynamic> map, {
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
  }) {
    FlutsterTestEvent? ret;
    Duration waitDuration = Duration(milliseconds: map["waitDuration"]);
    DateTime? time = DateTime.fromMillisecondsSinceEpoch(
        map["time"] ?? DateTime.now().millisecondsSinceEpoch);
    String? widgetName;
    if (map.containsKey("widgetName") && map["widgetName"] != "null") {
      widgetName = map["widgetName"];
    } else {
      widgetName = null;
    }
    switch (map["type"]) {
      case "key":
        PhysicalKeyboardKey? pk = map.getIfNotNull(
            "physicalKey.usbHidUsage", (value) => PhysicalKeyboardKey(value));
        if (map.containsKey("physicalKey.usbHidUsage")) {
          pk = PhysicalKeyboardKey(map["physicalKey.usbHidUsage"]);
        }
        LogicalKeyboardKey? lk = map.getIfNotNull(
            "logicalKey.keyId", (value) => LogicalKeyboardKey(value));
        String keyLabel = map.getIfNotNull("logicalKey.keyLabel");
        Duration kd = map.getIfNotNull(
                "keyEvent.duration",
                (value) => value == null
                    ? Duration.zero
                    : Duration(milliseconds: value)) ??
            Duration.zero;
        bool? keyEventDown = map.getIfNotNull("keyEventDown");
        KeyEvent? ke;
        if (pk != null && lk != null) {
          if (keyEventDown ?? true) {
            ke = KeyDownEvent(
              physicalKey: pk,
              logicalKey: lk,
              timeStamp: kd,
              character: map.getIfNotNull("character"),
            );
          } else {
            ke = KeyUpEvent(
              physicalKey: pk,
              logicalKey: lk,
              timeStamp: kd,
            );
          }
        }
        String typedText = map["typedText"];
        ret = FlutsterTestEvent.text(
          flutsterTestRecorderState: flutsterTestRecorderState,
          tester: tester,
          keyEvent: ke,
          typedText: typedText,
          time: time,
          keyLabel: keyLabel,
          widgetName: widgetName,
        );
        break;
      case "tap":
        Offset tapStart = Offset(
          double.parse(map["tapStart.dx"].toString()),
          double.parse(map["tapStart.dy"].toString()),
        );
        double? tapStopDx =
            double.tryParse(map.getIfNotNull("tapStop.dx").toString());
        double? tapStopDy =
            double.tryParse(map.getIfNotNull("tapStop.dy").toString());
        Offset? tapStop;
        if (tapStopDx != null && tapStopDy != null) {
          tapStop = Offset(
            tapStopDx,
            tapStopDy,
          );
        }
        Duration? tapDuration = map.getIfNotNull(
            "tapDuration", (value) => Duration(milliseconds: value));
        ret = FlutsterTestEvent.tap(
          flutsterTestRecorderState: flutsterTestRecorderState,
          tester: tester,
          tapStart: tapStart,
          time: time,
          tapDuration: tapDuration ?? const Duration(milliseconds: 0),
          tapStop: tapStop,
          widgetName: widgetName,
        );
        break;
      case "screenShot":
        Uint8List screenShotBytes = base64Decode(map["screenShot"]);
        Image screenShot = Image.memory(screenShotBytes);
        ret = FlutsterTestEvent.screenShot(
          flutsterTestRecorderState: flutsterTestRecorderState,
          tester: tester,
          screenShot: screenShot,
          screenShotBytes: screenShotBytes,
          time: time,
          widgetName: widgetName,
        );
        String screenShotComparisonFunctionName =
            map["screenShotComparisonFunctionName"] ??
                defaultScreenshotComparisonFunctionName;
        double screenShotAcceptancePctThreshold =
            double.parse(map["screenShotAcceptancePctThreshold"].toString());
        double pixelMatchingTolerance =
            double.parse(map["pixelMatchingTolerance"].toString());
        double iMEDBlurRatio = double.parse(map["IMEDBlurRatio"].toString());
        double iMEDSigma = double.parse(map["IMEDSigma"].toString());
        ret.screenShotComparisonFunctionName = screenShotComparisonFunctionName;
        ret.screenShotAcceptancePctThreshold = screenShotAcceptancePctThreshold;
        ret.pixelMatchingTolerance = pixelMatchingTolerance;
        ret.iMEDBlurRatio = iMEDBlurRatio;
        ret.iMEDSigma = iMEDSigma;
        break;
      default:
        assert(false, "Unknown FlutsterTestEvent type in fromMap");
        break;
    }
    ret!.waitDuration = waitDuration;
    return (ret);
  }

  /// [toJson] returns the event as a json string.
  String toJson() {
    return (jsonEncode(toMap()));
  }

  /// [fromJson] factory returns an event made from a json string.
  factory FlutsterTestEvent.fromJson(
    String json, {
    FlutsterTestRecorderState? flutsterTestRecorderState,
    WidgetTester? tester,
  }) {
    return (FlutsterTestEvent.fromMap(
      jsonDecode(json),
      flutsterTestRecorderState: flutsterTestRecorderState,
      tester: tester,
    ));
  }

  //returns true if the key event means the previously recorded string can be
  // considered ended.
  bool isStopKey() {
    const List<LogicalKeyboardKey> stopKeys = [
      LogicalKeyboardKey.save,
      LogicalKeyboardKey.abort,
      LogicalKeyboardKey.appSwitch,
      LogicalKeyboardKey.cancel,
      LogicalKeyboardKey.close,
      LogicalKeyboardKey.exit,
      LogicalKeyboardKey.navigateNext,
      LogicalKeyboardKey.navigatePrevious,
      LogicalKeyboardKey.tab,
    ];
    return (stopKeys.contains(keyEvent!.logicalKey));
  }

  /// [characterCharacter] returns the keyEvent.character if any.
  String characterCharacter() {
    return (keyEvent?.character ?? "");
  }

  /// [isCharacterAZ] returns true if the keyEvent.character is printable.
  bool isCharacterAZ() {
    String chars = characterCharacter();
    if (chars.isEmpty) {
      return (false);
    }
    for (var char in chars.runes) {
      if (char <= 31) {
        return (false);
      }
      if (char >= 127 && char <= 159) {
        return (false);
      }
    }
    return (true);
  }

  /// [isAZ] returns true if the keyEvent.logicalKey is between 'a' and 'z'.
  bool isAZ() {
    const List<LogicalKeyboardKey> aZKeys = [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyP,
      LogicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyU,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyY,
      LogicalKeyboardKey.keyZ,
    ];
    return (aZKeys.contains(keyEvent!.logicalKey));
  }

  /// [character] tries to get the character from the keyEvent. If it fails, it
  /// tries the correspondence from the keyEvent.logicalKey.
  String character() {
    if (keyEvent?.character != null) {
      return (keyEvent!.character!);
    }
    Map<LogicalKeyboardKey, String> keyToChar = {
      LogicalKeyboardKey.keyA: "a",
      LogicalKeyboardKey.keyB: "b",
      LogicalKeyboardKey.keyC: "c",
      LogicalKeyboardKey.keyD: "d",
      LogicalKeyboardKey.keyE: "e",
      LogicalKeyboardKey.keyF: "f",
      LogicalKeyboardKey.keyG: "g",
      LogicalKeyboardKey.keyH: "h",
      LogicalKeyboardKey.keyI: "i",
      LogicalKeyboardKey.keyJ: "j",
      LogicalKeyboardKey.keyK: "k",
      LogicalKeyboardKey.keyL: "l",
      LogicalKeyboardKey.keyM: "m",
      LogicalKeyboardKey.keyN: "n",
      LogicalKeyboardKey.keyO: "o",
      LogicalKeyboardKey.keyP: "p",
      LogicalKeyboardKey.keyQ: "q",
      LogicalKeyboardKey.keyR: "r",
      LogicalKeyboardKey.keyS: "s",
      LogicalKeyboardKey.keyT: "t",
      LogicalKeyboardKey.keyU: "u",
      LogicalKeyboardKey.keyV: "v",
      LogicalKeyboardKey.keyW: "w",
      LogicalKeyboardKey.keyX: "x",
      LogicalKeyboardKey.keyY: "y",
      LogicalKeyboardKey.keyZ: "z",
      LogicalKeyboardKey.digit0: "0",
      LogicalKeyboardKey.digit1: "1",
      LogicalKeyboardKey.digit2: "2",
      LogicalKeyboardKey.digit3: "3",
      LogicalKeyboardKey.digit4: "4",
      LogicalKeyboardKey.digit5: "5",
      LogicalKeyboardKey.digit6: "6",
      LogicalKeyboardKey.digit7: "7",
      LogicalKeyboardKey.digit8: "8",
      LogicalKeyboardKey.digit9: "9",
      LogicalKeyboardKey.underscore: "_",
      LogicalKeyboardKey.minus: "-",
      LogicalKeyboardKey.dollar: "\$",
      LogicalKeyboardKey.exclamation: "!",
      LogicalKeyboardKey.ampersand: "&",
      LogicalKeyboardKey.at: "@",
      LogicalKeyboardKey.add: "+",
      LogicalKeyboardKey.question: "?",
      LogicalKeyboardKey.tilde: "~",
      LogicalKeyboardKey.space: " ",
      LogicalKeyboardKey.slash: "/",
      LogicalKeyboardKey.parenthesisLeft: "(",
      LogicalKeyboardKey.parenthesisRight: ")",
      LogicalKeyboardKey.braceLeft: "{",
      LogicalKeyboardKey.braceRight: "}",
      LogicalKeyboardKey.bracketLeft: "[",
      LogicalKeyboardKey.bracketRight: "]",
      LogicalKeyboardKey.asterisk: "*",
      LogicalKeyboardKey.equal: "=",
      LogicalKeyboardKey.quote: "\"",
      LogicalKeyboardKey.quoteSingle: "'",
      LogicalKeyboardKey.backquote: "`",
      LogicalKeyboardKey.caret: "^",
      LogicalKeyboardKey.percent: "%",
      LogicalKeyboardKey.period: ".",
      LogicalKeyboardKey.semicolon: ";",
      LogicalKeyboardKey.comma: ",",
      LogicalKeyboardKey.colon: ":",
      LogicalKeyboardKey.bar: "|",
      LogicalKeyboardKey.backslash: "\\",
      LogicalKeyboardKey.numberSign: "#",
      LogicalKeyboardKey.less: "<",
      LogicalKeyboardKey.greater: ">",
    };
    if (keyToChar.containsKey(keyEvent!.logicalKey)) {
      return (keyToChar[keyEvent!.logicalKey]!);
    }
    return ("");
  }

  /// [keyToSwallow] returns true if the keyLabel is considered as not useful
  /// in a combine and can be removed.
  bool keyToSwallow() {
    List<String> keyLabelsToSwallow = [
      "Shift Right",
      "Shift Left",
      "Num Lock",
    ];
    if (keyLabelsToSwallow.contains(keyLabel)) {
      return (true);
    }
    return (false);
  }

  /// [combineAll] combines all the key events in the record that can be
  /// combined.
  /// Returns true if "this" event would combine previous one and thus the
  /// previous one can be deleted.
  Future<bool> combineAll(
      {String text = "",
      List<LogicalKeyboardKey>? keysToCloseUp,
      int cursorPosition = 0}) async {
    FlutsterTestEvent? next = (await getRecord())?.findNextEvent(this);
    if (type != FlutsterTestEventType.key ||
        isStopKey() ||
        (LogicalKeyboardKey.isControlCharacter(keyEventKeyLabel ?? "") &&
            keyEvent!.logicalKey != LogicalKeyboardKey.backspace)) {
      next?.combineAll(
        keysToCloseUp: keysToCloseUp,
      );
      return (false);
    }
    keysToCloseUp ??= [];
    if (keyEvent?.logicalKey != null) {
      if (keyEventDown ?? true) {
        if (isCharacterAZ()) {
          if (keysToCloseUp.contains(LogicalKeyboardKey.shift) ||
              keysToCloseUp.contains(LogicalKeyboardKey.shiftLeft) ||
              keysToCloseUp.contains(LogicalKeyboardKey.shiftLevel5) ||
              keysToCloseUp.contains(LogicalKeyboardKey.shiftRight)) {
            text = text.replaceRange(cursorPosition, cursorPosition,
                characterCharacter().toUpperCase());
            typedText = text;
          } else {
            text = text.replaceRange(
                cursorPosition, cursorPosition, characterCharacter());
            typedText = text;
          }
          cursorPosition++;
        } else if (keyEvent!.logicalKey == LogicalKeyboardKey.arrowLeft ||
            keyLabel == "Arrow Left") {
          cursorPosition--;
          if (cursorPosition < 0) {
            cursorPosition = 0;
          }
        } else if (keyEvent!.logicalKey == LogicalKeyboardKey.arrowRight ||
            keyLabel == "Arrow Right") {
          cursorPosition++;
          if (cursorPosition > text.length) {
            cursorPosition = text.length;
          }
        } else if (keyEvent!.logicalKey == LogicalKeyboardKey.end ||
            keyLabel == "End") {
          cursorPosition = text.length;
        } else if (keyEvent!.logicalKey == LogicalKeyboardKey.home ||
            keyLabel == "Home") {
          cursorPosition = 0;
        } else if (keyEvent!.logicalKey == LogicalKeyboardKey.backspace ||
            keyLabel == "Backspace") {
          if (cursorPosition > 0) {
            text = text.replaceRange(cursorPosition - 1, cursorPosition, "");
            cursorPosition--;
          }
        } else if (keyEvent!.logicalKey == LogicalKeyboardKey.delete ||
            keyLabel == "Delete") {
          if (cursorPosition < text.length) {
            text = text.replaceRange(cursorPosition, cursorPosition + 1, "");
            // typedText=text;
          }
        } else if (isAZ()) {
          if (keysToCloseUp.contains(LogicalKeyboardKey.shift) ||
              keysToCloseUp.contains(LogicalKeyboardKey.shiftLeft) ||
              keysToCloseUp.contains(LogicalKeyboardKey.shiftLevel5) ||
              keysToCloseUp.contains(LogicalKeyboardKey.shiftRight)) {
            text = text.replaceRange(
                cursorPosition, cursorPosition, character().toUpperCase());
          } else {
            text =
                text.replaceRange(cursorPosition, cursorPosition, character());
          }
          cursorPosition++;
        } else {
          if (!keyToSwallow()) {
            next?.combineAll(
              keysToCloseUp: keysToCloseUp,
            );
            return (false);
          }
        }
        if (keyEventDown != null) {
          keysToCloseUp.add(keyEvent!.logicalKey);
        }
      } else {
        if (keysToCloseUp.isNotEmpty) {
          keysToCloseUp
              .removeWhere((element) => element == keyEvent!.logicalKey);
        }
      }
    }

    next = (await getRecord())?.findNextEvent(this);
    FlutsterTestEvent? previous = (await getRecord())?.findPreviousEvent(this);
    if (previous?.type != FlutsterTestEventType.key ||
        (previous?.isStopKey() ?? false)) {
      previous = null;
    } else {
      waitDuration = Duration(
          milliseconds: waitDuration!.inMilliseconds +
              (previous?.waitDuration?.inMilliseconds ?? 0));
    }

    if (await next?.combineAll(
          text: text,
          keysToCloseUp: keysToCloseUp,
          cursorPosition: cursorPosition,
        ) ??
        false) {
      (await getRecord())?.deleteEvent(this);
    }
    if (text.isNotEmpty && (typedText?.isEmpty ?? true)) {
      typedText = text;
    }
    return (true);
  }

  /// [strSummary] returns a printable summary of the event.
  String strSummary() {
    String ret = (waitDuration?.toString() ?? "");
    ret += " ${type.name}";
    switch (type) {
      case FlutsterTestEventType.tap:
        ret += "; ${tapSummaryStr()}";
        break;
      case FlutsterTestEventType.key:
        ret += "; ${typedText ?? ""}";
        break;
      case FlutsterTestEventType.screenShot:
        String fnName = screenShotComparisonFunctionName ??
            defaultScreenshotComparisonFunctionName;
        ret +=
            "; function: $fnName; acceptance pct: $screenShotAcceptancePctThreshold";
        if (fnName == "Pixel - Matching") {
          ret +=
              "; pixel matching tolerance: $screenShotAcceptancePctThreshold";
        }
        if (fnName == "Pixel - IMED") {
          ret += "; iMED sigma: $iMEDSigma; iMED blur ratio: $iMEDBlurRatio";
        }
        ret += "; match result: ${screenShotMatchResult?.toString() ?? "none"}";
        ret += "; screenShotB42: ${screenShotToB64()}";
        break;
      default:
        ret += "; unknown event type for summary";
        break;
    }
    return (ret);
  }

  /// [tapSummaryStr] returns part of the [strSummary] in case of a tap event.
  String tapSummaryStr() {
    return ("( ${tapStart!.dx.round()} , ${tapStart!.dy.round()} )${tapDuration == null || tapDuration!.inSeconds < 1 ? "" : " ${tapDuration!.inSeconds}s"}${tapStop == null || (tapStart! - tapStop!).distance.abs() < 2 ? "" : " -> ( ${tapStop!.dx.round()} , ${tapStop!.dy.round()} )"}");
  }
}

/// [ifJsonAble] returns the given string if it can be json encoded and decoded.
/// Returns null otherwise.
String? ifJsonAble(String? character) {
  List<String> forbiddenChars = [
    "\t",
    "\u0000",
    "\u{0000}",
  ];
  if (forbiddenChars.contains(character)) {
    return (null);
  }
  try {
    String json = jsonEncode(
      character,
    );
    return (jsonDecode(json) == character ? character : null);
  } catch (e) {
    return (null);
  }
}

/// [FlutsterStateKeeper] is meant to hold a [FlutsterTestRecorderState].
class FlutsterStateKeeper {
  /// [_state] is the private value that is kept.
  FlutsterTestRecorderState? _state;

  /// [state] getter returns the state.
  FlutsterTestRecorderState? get state {
    return (_state);
  }

  /// [state] setter assigns a value to the state.
  set state(FlutsterTestRecorderState? value) {
    _state = value;
  }
}

/// [FlutsterTestRecorder] is the main UI element to record and replay tests.
class FlutsterTestRecorder extends StatefulWidget {
  /// [positionKey] is used to determine the render box.
  final GlobalKey positionKey = GlobalKey();

  /// [child] is the widget to be displayed and tested.
  final Widget child;

  /// [givenFlutsterTestRecord] is the place where the test events are stored.
  final FlutsterTestRecord? givenFlutsterTestRecord;

  /// [stateKeeper] is used to hold the state.
  final FlutsterStateKeeper stateKeeper = FlutsterStateKeeper();

  /// [name] is used to retrieve the right [FlutsterTestRecorder] while running
  /// the test.
  final String? name;

  /// [flutsterTestRecord] returns the [givenFlutsterTestRecord] if not null and
  /// FlutsterTestRecord.defaultRecord otherwise.
  FlutsterTestRecord get flutsterTestRecord {
    return (givenFlutsterTestRecord ?? FlutsterTestRecord.defaultRecord);
  }

  /// [FlutsterTestRecorder] constructor supports arguments which descriptions
  /// are available individually in the list of class fields.
  FlutsterTestRecorder({
    Key key = const Key("FlutsterTestRecorder"),
    required this.child,
    this.givenFlutsterTestRecord,
    this.name,
  }) : super(key: key);

  /// [createState] as with any StateFulWidget.
  @override
  State<FlutsterTestRecorder> createState() => FlutsterTestRecorderState();

  /// [registerWith] is necessary for this dart only plugin
  static void registerWith() {}
}

/// [FlutsterTestRecorderState] is the state of the [FlutsterTestRecorder].
class FlutsterTestRecorderState extends State<FlutsterTestRecorder> {
  /// [focusNode] is the keyboard listener focus node.
  final FocusNode focusNode = FocusNode();

  /// [floatingButtonPosition] keeps track of the Flutster floating button
  /// position.
  Offset? floatingButtonPosition;

  /// [buttonSize] is the size of each side of the Flutster floating button.
  double buttonSize = 50;

  /// [buttonSizeMaxProportion] shrinks the Flutster floating button if the
  /// screen height or width is smaller than the button divided by the
  /// proportion.
  double buttonSizeMaxProportion = 0.2;

  /// [latestFABPressed] is used to handle the double click on the Flutster
  /// floating button.
  DateTime latestFABPressed = DateTime.now();

  /// [doublePressDelay] is the maximum time the user can click a second time on
  /// the Flutster floating button to consider a double click.
  final Duration doublePressDelay = const Duration(milliseconds: 600);

  /// [screenKey] helps in retrieving a screenshot.
  GlobalKey screenKey = GlobalKey();

  /// [testNameFieldController] is the text field controller for the test name.
  TextEditingController testNameFieldController = TextEditingController();

  /// [apiSaveOngoing] is true when the test record is being saved to the
  /// Flutster API.
  bool apiSaveOngoing = false;

  /// [apiDeleteOngoing] is true when the test record is being deleted from the
  /// Flutster API.
  bool apiDeleteOngoing = false;

  /// [apiListingOngoing] is true when the test records are being listed from
  /// the Flutster API.
  bool apiListingOngoing = false;

  /// [apiLoadOngoing] is true when the test record is being loaded from the
  /// Flutster API.
  bool apiLoadOngoing = false;

  /// [initState] as with any stateful widget state.
  @override
  void initState() {
    widget.stateKeeper.state = this;
    super.initState();
  }

  /// [build] as with any stateful widget state.
  @override
  Widget build(BuildContext context) {
    widget.stateKeeper.state ??= this;
    if (!widget.flutsterTestRecord.active) {
      return (widget.child);
    }
    RenderBox? box =
        widget.positionKey.currentContext?.findRenderObject() as RenderBox?;
    Offset position = const Offset(0, 0);
    if (box != null) {
      position = box.localToGlobal(Offset.zero);
      if (buttonSize > box.size.width * buttonSizeMaxProportion) {
        buttonSize = box.size.width * buttonSizeMaxProportion;
      }
      if (buttonSize > box.size.height * buttonSizeMaxProportion) {
        buttonSize = box.size.height * buttonSizeMaxProportion;
      }
      if (widget.flutsterTestRecord.buttonSize != null) {
        buttonSize = widget.flutsterTestRecord.buttonSize!;
      }
    }
    double newX = (floatingButtonPosition?.dx ?? 0) - position.dx;
    double newY = (floatingButtonPosition?.dy ?? 0) - position.dy;
    if (newX < 0) {
      newX = 0;
    }
    if (newY < 0) {
      newY = 0;
    }
    if (box != null) {
      if (newX > box.size.width - buttonSize) {
        newX = box.size.width - buttonSize;
      }
      if (newY > box.size.height - buttonSize) {
        newY = box.size.height - buttonSize;
      }
    } else {
      Future.delayed(const Duration(milliseconds: 500)).whenComplete(() {
        try {
          setState(() {});
        } catch (e) {
          debugPrint("Warning: failed to set state without box.");
        }
      });
    }
    return Stack(
      key: widget.positionKey,
      children: [
        KeyboardListener(
          focusNode: focusNode,
          onKeyEvent: (keyEvent) {
            String? text = keyEvent.character;
            widget.flutsterTestRecord.add(FlutsterTestEvent.text(
                flutsterTestRecorderState: this,
                typedText: ifJsonAble(text) ?? "",
                keyEvent: keyEvent,
                widgetName: widget.name));
          },
          child: Listener(
            onPointerDown: (pointerDownEvent) {
              widget.flutsterTestRecord.add(FlutsterTestEvent.tap(
                  flutsterTestRecorderState: this,
                  tapStart: pointerDownEvent.position,
                  widgetName: widget.name));
            },
            onPointerUp: (pointerUpEvent) {
              widget.flutsterTestRecord.tapUp(pointerUpEvent.position);
            },
            child: RepaintBoundary(
              key: screenKey,
              child: widget.child,
            ),
          ),
        ),
        Positioned(
          left: newX,
          top: newY,
          child: SizedBox(
            height: buttonSize,
            width: buttonSize,
            child: Draggable(
              feedback: SizedBox(
                height: buttonSize,
                width: buttonSize,
                child: buildFAB(setState),
              ),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  floatingButtonPosition = details.offset;
                });
              },
              child: buildFAB(setState),
            ),
          ),
        ),
      ],
    );
  }

  /// [fABPressed] is called when the Flutster floating button is pressed.
  void fABPressed(void Function(VoidCallback fn) updateParent) {
    DateTime now = DateTime.now();
    if (now.difference(latestFABPressed) > doublePressDelay) {
      latestFABPressed = now;
      Future.delayed(doublePressDelay).whenComplete(() {
        if (latestFABPressed == now) {
          openFlutsterTestMenu(updateParent);
        }
      });
    } else {
      latestFABPressed = now;
      if (widget.flutsterTestRecord.recording) {
        takeScreenShot(updateParent);
      }
    }
  }

  /// [openFlutsterTestMenu] is called to open the Flutster test menu.
  void openFlutsterTestMenu(void Function(VoidCallback fn) updateParent) {
    int nbEvents = widget.flutsterTestRecord.events.length;
    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(builder: (context, StateSetter setState) {
            testNameFieldController.text = widget.flutsterTestRecord.testName;
            String wName = widget.name == null ? "" : " (${widget.name})";
            return AlertDialog(
              contentPadding: const EdgeInsets.all(3.0),
              buttonPadding: const EdgeInsets.all(3.0),
              insetPadding: const EdgeInsets.all(8.0),
              titlePadding: const EdgeInsets.all(3.0),
              title: Text("Flutster test recorder$wName"),
              content: Scaffold(
                body: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Wrap(
                      runSpacing: 6,
                      children: [
                        TextFormField(
                          controller: testNameFieldController,
                          autovalidateMode: AutovalidateMode.always,
                          decoration: const InputDecoration(
                            labelText: "Test name",
                          ),
                          validator: FlutsterTestRecord.testNameValidator,
                          onChanged: (testName) {
                            if (FlutsterTestRecord.testNameValidator(
                                    testName) ==
                                null) {
                              widget.flutsterTestRecord.testName = testName;
                            }
                          },
                        ),
                        widget.flutsterTestRecord.id == null
                            ? const SizedBox.shrink()
                            : Center(
                                child: Text("API test record id: "
                                    "${widget.flutsterTestRecord.id}")),
                        widget.flutsterTestRecord.events.isEmpty
                            ? const Center(
                                child: Text(
                                    "No Flutster test events recorded yet."))
                            : Center(
                                child: Text(
                                  "$nbEvents"
                                  " Flutster test event"
                                  "${nbEvents == 1 ? "" : "s"}"
                                  " recorded.",
                                ),
                              ),
                        ...widget.flutsterTestRecord.events
                            .map<Widget>((event) => event.build(
                                  setState,
                                  widget.flutsterTestRecord.events,
                                  context,
                                ))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.all(0.0),
              actionsOverflowButtonSpacing: 0.0,
              actionsOverflowDirection: VerticalDirection.down,
              actionsAlignment: MainAxisAlignment.end,
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    deleteTestRecordButton(context, setState),
                    clearTestRecordButton(context, setState),
                    loadTestRecordFromClipboardButton(context, setState),
                    shareTestRecordButton(context, setState),
                    saveTestRecordToApiButton(context, setState),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    selectTestRecordFromApiButton(context, setState),
                    stopDisplayingFlutsterButton(context, updateParent),
                    takeScreenShotButton(context, setState, updateParent),
                    widget.flutsterTestRecord.recording
                        ? stopRecordingButton(context, setState, updateParent)
                        : startRecordingButton(context, setState, updateParent),
                    IconButton(
                      padding: const EdgeInsets.all(0.0),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        closeTestRecordDialog();
                      },
                    ),
                  ],
                ),
              ],
            );
          });
        });
  }

  /// [share] is called when the user wants to share the Flutster test record.
  share() {
    widget.flutsterTestRecord.share(
      context,
    );
    setState(() {});
  }

  /// [confirmedAction] is called to let the user confirm an action.
  confirmedAction({
    required BuildContext context,
    String? title,
    required String message,
    String cancelText = "Cancel",
    String okText = "Ok",
    String? sosoText,
    required Function() onOk,
    Function()? onSoso,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title == null ? null : Text(title),
          content: Text(message),
          actions: [
            ElevatedButton(
              child: Text(cancelText),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            sosoText == null
                ? const SizedBox.shrink()
                : ElevatedButton(
                    child: Text(sosoText),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSoso!();
                    },
                  ),
            ElevatedButton(
              child: Text(okText),
              onPressed: () {
                Navigator.of(context).pop();
                onOk();
              },
            ),
          ],
        );
      },
    );
  }

  /// [returnScreenShotPngBytes] takes a screenshot of the child widget and
  /// returns the bytes of the png file.
  Future<Uint8List?> returnScreenShotPngBytes(
      {int retries = 100, WidgetTester? tester}) async {
    Uint8List? pngBytes;
    try {
      await Future.delayed(const Duration(milliseconds: 100), () async {
        RenderRepaintBoundary? boundary = screenKey.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          return (Future.value(null));
        }
        if (boundary.debugNeedsPaint && retries > 0) {
          debugPrint("Waiting for boundary to be painted (retries left: "
              "${retries.toString()}).");
          if (tester != null) {
            await tester.pumpAndSettle();
          }
          await Future.delayed(const Duration(milliseconds: 500));
          return (await returnScreenShotPngBytes(
              retries: retries - 1, tester: tester));
        }
        ui.Image uIImage = await boundary.toImage();
        var byteData = await uIImage.toByteData(format: ImageByteFormat.png);
        pngBytes = byteData?.buffer.asUint8List();
      });
    } catch (e, st) {
      debugPrint("Warning: cannot get screenshot (retries left: "
          "${retries.toString()}): ${e.toString()} ${st.toString()}");
    }
    if (retries <= 0) {
      return (pngBytes);
    }
    if (pngBytes == null) {
      return (await returnScreenShotPngBytes(
          retries: retries - 1, tester: tester));
    }
    return (pngBytes);
  }

  /// [returnScreenShot] takes and returns the screenshot as an image.
  Future<Image?> returnScreenShot() async {
    Uint8List? pngBytes = await returnScreenShotPngBytes();
    if (pngBytes == null) {
      return (Future.value(null));
    }
    Image image = Image.memory(pngBytes);
    return (image);
  }

  /// [returnScreenShotEvent] takes a screenshot and returns it as a test event.
  Future<FlutsterTestEvent?> returnScreenShotEvent(
      {FlutsterTestEvent? duplicate, WidgetTester? tester}) async {
    Uint8List? pngBytes = await returnScreenShotPngBytes(tester: tester);
    if (pngBytes == null) {
      return (Future.value(null));
    }
    Image image = Image.memory(pngBytes);
    FlutsterTestEvent? screenShotEvent;
    if (duplicate != null) {
      screenShotEvent = FlutsterTestEvent.fromMap(
        duplicate.toMap(),
        flutsterTestRecorderState: this,
      );
      screenShotEvent.screenShot = image;
      screenShotEvent.screenShotBytes = pngBytes;
    } else {
      screenShotEvent = FlutsterTestEvent.screenShot(
          flutsterTestRecorderState: this,
          screenShot: image,
          screenShotBytes: pngBytes,
          widgetName: widget.name);
    }
    return (screenShotEvent);
  }

  /// [takeScreenShot] takes the screenshot and saves the event in the record.
  Future<void> takeScreenShot(
      void Function(VoidCallback fn) updateParent) async {
    FlutsterTestEvent? screenShotEvent = await returnScreenShotEvent();
    if (screenShotEvent == null) {
      snack(const Text("Failed to take screenshot"));
      return;
    }
    widget.flutsterTestRecord.add(screenShotEvent);
    snack(const Text("Screenshot taken"));
    updateParent(() {});
  }

  /// [snack] displays a snack with the given content (string or widget).
  void snack(dynamic content, [BuildContext? givenContext]) {
    snackStatic(
      content,
      givenContext ?? context,
    );
  }

  /// [snackStatic] displays a snack with the given content (string or widget).
  /// This static function requires the context
  static void snackStatic(dynamic content, BuildContext givenContext) {
    ScaffoldMessenger.of(givenContext).showSnackBar(SnackBar(
      content: (content is Widget)
          ? content
          : (content is String)
              ? Text(content)
              : const Text("Unknown content type"),
    ));
  }

  /// [buildFAB] returns the Flutster floating button widget.
  Widget buildFAB(void Function(VoidCallback fn) setState) {
    if (!displayFlutsterButton) {
      return (const SizedBox.shrink());
    }
    return (FloatingActionButton(
      // heroTag: "FlutsterFAB",
      heroTag: null,
      shape: widget.flutsterTestRecord.recording
          ? const CircleBorder()
          : const RoundedRectangleBorder(),
      backgroundColor:
          widget.flutsterTestRecord.recording ? Colors.red : Colors.blue,
      mini: true,
      child: Icon(
        Icons.drag_handle,
        size: buttonSize * 0.5,
        color: Colors.white,
      ),
      onPressed: () {
        fABPressed(setState);
      },
    ));
  }

  /// [playEvent] plays the given event on the child widget.
  Future<FlutsterTestEvent?> playEvent(
    FlutsterTestEvent flutsterTestEvent, {
    Duration delay = const Duration(milliseconds: 0),
    WidgetTester? tester,
  }) async {
    switch (flutsterTestEvent.type) {
      case FlutsterTestEventType.screenShot:
        FlutsterTestEvent? ret;
        if (tester != null) {
          await tester.pumpAndSettle();
        }
        await Future.delayed(delay).whenComplete(() async {
          ret = await returnScreenShotEvent(
              duplicate: flutsterTestEvent, tester: tester);
        });
        return (ret);
      case FlutsterTestEventType.tap:
        WidgetController? controller;
        if (tester == null) {
          controller = LiveWidgetController(WidgetsBinding.instance);
        } else {
          controller = tester;
        }
        if (flutsterTestEvent.tapDuration == null ||
            flutsterTestEvent.tapStop == null) {
          await Future.delayed(delay).whenComplete(() async {
            await controller!.tapAt(
              flutsterTestEvent.tapStart!,
            );
          });
        } else {
          await Future.delayed(delay).whenComplete(() async {
            TestGesture gesture = await controller!.startGesture(
              flutsterTestEvent.tapStart!,
              kind: PointerDeviceKind.touch,
            );
            await gesture.moveTo(flutsterTestEvent.tapStop!,
                timeStamp: flutsterTestEvent.tapDuration!);
            await gesture.up();
            await controller.pump();
          });
        }
        return (flutsterTestEvent);
      case FlutsterTestEventType.key:
        if (tester == null) {
          snack(const Text("Cannot replay key events in a non test situation"));
          return (null);
        }
        FlutsterTestEvent? ret = flutsterTestEvent;
        await Future.delayed(delay).whenComplete(() async {
          bool keyDown = false;
          if (flutsterTestEvent.keyEvent is KeyDownEvent ||
              flutsterTestEvent.keyEvent is RawKeyDownEvent ||
              (flutsterTestEvent.keyEventDown ?? false)) {
            keyDown = true;
          }
          if (flutsterTestEvent.typedText?.isEmpty ?? true) {
            if (keyDown) {
              if (!await tester
                  .sendKeyDownEvent(flutsterTestEvent.keyEvent!.logicalKey)) {
                ret = null;
              }
            } else {
              if (!await tester.sendKeyUpEvent(
                flutsterTestEvent.keyEvent!.logicalKey,
              )) {
                debugPrint(
                    "send key up returned false, not stopping the test run for "
                    "that");
              }
              await tester.pumpAndSettle();
            }
          } else {
            tester.testTextInput.enterText(flutsterTestEvent.typedText ?? "");
            await tester.pumpAndSettle();
          }
        });
        return (ret);
      default:
        return (null);
    }
  }

  /// [save] saves the record to the https://flutster.com API.
  void save(Function snackHere, Function() updateUI) async {
    apiSaveOngoing = true;
    updateUI();
    String? res;
    try {
      res = await widget.flutsterTestRecord.apiSave();
    } catch (e, st) {
      res = "Failed to save test record";
      debugPrint("$e $st");
    }
    apiSaveOngoing = false;
    snackHere(res);
    updateUI();
  }

  /// [strDtToStr] helps in standardizing the date string format.
  String strDtToStr(String s) {
    DateFormat formatter = DateFormat("yyyy-MM-dd hh:mm:ss");
    try {
      formatter = DateFormat.Hms(Localizations.localeOf(context).languageCode)
          .add_yMd();
    } catch (e) {
      initializeDateFormatting();
      try {
        formatter = DateFormat.Hms(Localizations.localeOf(context).languageCode)
            .add_yMd();
      } catch (e, st) {
        debugPrint("$e $st");
        formatter = DateFormat("yyyy-MM-dd hh:mm:ss");
      }
    }
    String dtStr = s;
    DateTime? dt = DateTime.tryParse('${s}Z')?.toLocal();
    if (dt != null) {
      dtStr = formatter.format(dt);
    }
    return (dtStr);
  }

  /// [selectFromApiList] lets the user choose from the list of test records
  /// from the https://flutster.com API.
  void selectFromApiList(
    BuildContext context,
    Function() updateUI,
    Function(
      BuildContext context,
      Function() updateUI,
      int? testRecordId,
      Function(
        dynamic content,
      )
          snackHere,
    )
        apiLoad,
    Function(
      dynamic content,
    )
        snackHere,
  ) async {
    apiListingOngoing = true;
    updateUI();
    String? res;
    try {
      res = await widget.flutsterTestRecord.apiListing();
    } catch (e, st) {
      res = "Failed to list test records from API";
      debugPrint("$e $st");
    }
    try {
      if (res.startsWith('{"error":')) {
        Map<String, dynamic> err = jsonDecode(res);
        String mess;
        if (err.containsKey("message")) {
          mess = " ";
          mess += err["message"];
        } else {
          mess = "";
        }
        debugPrint(err["error"] + " " + mess);
        if (mess.contains("<") && mess.contains(">")) {
          mess = "";
        }
        snackHere("Failed to get API records: ${err["error"] + mess}");
      } else if (!res.startsWith("{") && !res.startsWith("[")) {
        snackHere("Failed to contact API: $res");
      } else {
        List<dynamic> resObj;
        resObj = jsonDecode(res);
        Map<String, dynamic> keys = {
          "id": "API test record id",
          "name": "Name",
          "created": (value) => makeLabelValueBlock(
              "Created", strDtToStr(value),
              tooltip: value + " API time"),
          "updated": (value) => makeLabelValueBlock(
              "Updated", strDtToStr(value),
              tooltip: value + " API time"),
          "active": (value) => makeLabelValueBlock(
              "Active", value.toString() == "1" ? "true" : "false"),
          "emailOnSuccess": (value) => makeLabelValueBlock(
              "Email on success", value.toString() == "1" ? "true" : "false"),
          "emailOnFailure": (value) => makeLabelValueBlock(
              "Email on failure", value.toString() == "1" ? "true" : "false"),
          "notes": "Notes",
        };
        List<Widget> listing = [];
        for (var entry in resObj) {
          Map<String, dynamic> testRecordEntry = entry as Map<String, dynamic>;
          listing.add(InkWell(
            onTap: () {
              apiLoad(
                context,
                updateUI,
                int.tryParse(entry["id"].toString()),
                (dynamic content) {
                  snack(content, context);
                },
              );
              Navigator.of(context).pop();
            },
            child: Card(
              elevation: 7,
              borderOnForeground: true,
              shadowColor: Colors.grey,
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: keys
                        .map<String, Widget>((key, label) {
                          Widget w = const SizedBox.shrink();
                          if (testRecordEntry.containsKey(key) &&
                              testRecordEntry[key] != null) {
                            dynamic value = testRecordEntry[key];
                            if (value is String || value is int) {
                              if (value.toString().isNotEmpty) {
                                if (label is Function) {
                                  w = label(value);
                                } else {
                                  w = makeLabelValueBlock(label, value);
                                }
                              }
                            }
                          }
                          return (MapEntry(
                              key,
                              Padding(
                                padding: const EdgeInsets.all(3),
                                child: w,
                              )));
                        })
                        .values
                        .toList()),
              ),
            ),
          ));
        }
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: listing.isNotEmpty
                  ? const Text("Select API test record to load")
                  : const Text(
                      "No test record on API. Record and save one with the "
                      "following actions:"),
              content: SingleChildScrollView(
                child: listing.isNotEmpty
                    ? Column(
                        children: listing,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Text(
                                  "1. Start recording:",
                                ),
                                startRecordingButton(context, setState,
                                    (Function doInUpdate) {
                                  doInUpdate();
                                  updateUI();
                                }),
                              ],
                            ),
                          ),
                          const Text(
                            "2. Use scrcpy with computer keyboard to type text",
                            softWrap: true,
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  "3. Take screenshot(s):",
                                ),
                                takeScreenShotButton(context, setState,
                                    (Function doInUpdate) {
                                  doInUpdate();
                                  updateUI();
                                }),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  "4. Stop recording:",
                                ),
                                stopRecordingButton(context, setState,
                                    (Function doInUpdate) {
                                  doInUpdate();
                                  updateUI();
                                }),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  "5. Save test record to API:",
                                ),
                                saveTestRecordToApiButton(
                                  context,
                                  setState,
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "6. Run the integration testing with the recorded "
                            "test record id.",
                            softWrap: true,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            "7. View the results on flutster.com .",
                            softWrap: true,
                          ),
                        ],
                      ),
              ),
              actions: [
                ElevatedButton(
                  child: const Text("cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e, st) {
      debugPrint("$e $st");
      snackHere("Failed to get API records");
    }
    apiListingOngoing = false;
    updateUI();
  }

  /// [makeLabelValueBlock] uniformizes the display of labels with values.
  Widget makeLabelValueBlock(
    String label,
    dynamic value, {
    String? tooltip,
  }) {
    Widget ret = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label:",
          style: const TextStyle(
            fontSize: 9,
            color: Colors.blue,
          ),
        ),
        Text(value.toString(), softWrap: true),
      ],
    );
    if (tooltip != null) {
      ret = Tooltip(
        message: tooltip,
        child: ret,
      );
    }
    return (ret);
  }

  /// [apiLoad] loads a record from the https://flutster.com API.
  apiLoad(
    BuildContext context,
    Function() updateUI,
    int? testRecordId,
    Function(dynamic) snackHere,
  ) async {
    if (testRecordId == null) {
      snack("Test record id is null, cannot load.", context);
      return;
    }
    apiLoadOngoing = true;
    updateUI();
    testNameFieldController.text = "";
    widget.flutsterTestRecord.clear();
    String? res;
    try {
      res = await widget.flutsterTestRecord.fromApi(
        testRecordId,
        flutsterTestRecorderState: this,
      );
    } catch (e, st) {
      res = "Failed to load test record from API";
      debugPrint("$e $st");
    }
    apiLoadOngoing = false;
    snackHere(
      res,
    );
    updateUI();
  }

  /// [deleteTestRecordButton] builds a button to delete the test record.
  Widget deleteTestRecordButton(
    BuildContext context,
    StateSetter setState,
  ) {
    Function snackHere;
    snackHere = (dynamic content) {
      snack(content, context);
    };
    return (apiDeleteOngoing
        ? const CircularProgressIndicator()
        : IconButton(
            padding: const EdgeInsets.all(0.0),
            icon: Icon(
              Icons.delete,
              color: widget.flutsterTestRecord.isCleared()
                  ? Colors.grey
                  : Colors.red,
            ),
            tooltip: "Delete this test record",
            onPressed: widget.flutsterTestRecord.isCleared()
                ? null
                : () {
                    confirmedAction(
                      context: context,
                      title: "Delete test record confirmation",
                      message:
                          "Please confirm the deletion of this test record.",
                      cancelText: "Cancel",
                      okText: "Ok",
                      sosoText: widget.flutsterTestRecord.id == null
                          ? null
                          : "Also API delete",
                      onOk: () {
                        testNameFieldController.text = "";
                        widget.flutsterTestRecord.clear();
                        setState(() {});
                      },
                      onSoso: () async {
                        setState(() {
                          apiDeleteOngoing = true;
                        });
                        String? res;
                        try {
                          res = await widget.flutsterTestRecord.apiDelete();
                        } catch (e) {
                          res = "Failed to delete test record";
                        }
                        apiDeleteOngoing = false;
                        snackHere(
                          res,
                        );
                        setState(() {});
                        testNameFieldController.text = "";
                        widget.flutsterTestRecord.clear();
                        setState(() {});
                      },
                    );
                  },
          ));
  }

  /// [clearTestRecordButton] builds a button to flush the test record, clear
  /// the test name, clear the test record id.
  Widget clearTestRecordButton(BuildContext context, StateSetter setState) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      icon: const Icon(
        Icons.clean_hands,
        color: Colors.blue,
      ),
      tooltip: "Clear test record",
      onPressed: () {
        confirmedAction(
          context: context,
          title: "Clear test record confirmation",
          message: "Confirm clearing test record",
          onOk: () async {
            testNameFieldController.text = "";
            widget.flutsterTestRecord.clear();
            setState(() {});
          },
        );
      },
    ));
  }

  /// [loadTestRecordFromClipboardButton] builds a button to load the test
  /// record from the clipboard.
  Widget loadTestRecordFromClipboardButton(
      BuildContext context, StateSetter setState) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      icon: const Icon(
        Icons.paste,
        color: Colors.blue,
      ),
      tooltip: "Load test from clipboard",
      onPressed: () {
        confirmedAction(
          context: context,
          title: "Load from clipboard confirmation",
          message: "Confirm loading test record from clipboard",
          onOk: () async {
            testNameFieldController.text = "";
            widget.flutsterTestRecord.clear();
            try {
              widget.flutsterTestRecord.fromJson(
                (await Clipboard.getData(Clipboard.kTextPlain))!.text!,
                flutsterTestRecorderState: this,
              );
            } catch (e, st) {
              snack(const Text("Invalid json"));
              debugPrint("Invalid json: ${e.toString()} ${st.toString()}");
            }
            setState(() {});
          },
        );
      },
    ));
  }

  /// [shareTestRecordButton] builds a button to share the test record.
  Widget shareTestRecordButton(BuildContext context, StateSetter setState) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      icon: Icon(
        Icons.share,
        color:
            widget.flutsterTestRecord.isCleared() ? Colors.grey : Colors.blue,
      ),
      tooltip: "Share this test record",
      onPressed: widget.flutsterTestRecord.isCleared()
          ? null
          : () {
              if (!widget.flutsterTestRecord.containsScreenShot()) {
                confirmedAction(
                  context: context,
                  title: "Share without screenshot confirmation",
                  message: "Share test record without a screenshot?",
                  onOk: () {
                    share();
                  },
                );
              } else {
                share();
              }
            },
    ));
  }

  /// [saveTestRecordToApiButton] builds a button to save the test record to the
  /// https://flutster.com API.
  Widget saveTestRecordToApiButton(BuildContext context, StateSetter setState) {
    return (apiSaveOngoing
        ? const CircularProgressIndicator()
        : IconButton(
            padding: const EdgeInsets.all(0.0),
            icon: Icon(
              Icons.cloud_upload,
              color: widget.flutsterTestRecord.isCleared()
                  ? Colors.grey
                  : Colors.blue,
            ),
            tooltip: "Save this test record to configured API",
            onPressed: () async {
              if (!widget.flutsterTestRecord.containsScreenShot()) {
                confirmedAction(
                  context: context,
                  title: "Save without screenshot confirmation",
                  message: "Save test record without a screenshot?",
                  onOk: () {
                    save((content) {
                      snack(content, context);
                    }, () {
                      setState(() {});
                    });
                  },
                );
              } else {
                save((content) {
                  snack(content, context);
                }, () {
                  setState(() {});
                });
              }
            },
          ));
  }

  /// [selectTestRecordFromApiButton] builds a button to select a test record
  /// from the https://flutster.com API.
  Widget selectTestRecordFromApiButton(
    BuildContext context,
    StateSetter setState,
  ) {
    return ((apiListingOngoing || apiLoadOngoing)
        ? const CircularProgressIndicator()
        : IconButton(
            padding: const EdgeInsets.all(0.0),
            icon: const Icon(
              Icons.cloud_download,
              color: Colors.blue,
            ),
            tooltip: "Load test record from configured API",
            onPressed: () {
              selectFromApiList(
                context,
                () {
                  setState(() {});
                },
                apiLoad,
                (content) {
                  snack(content, context);
                },
              );
            },
          ));
  }

  /// [stopDisplayingFlutsterButton] builds a button to stop displaying the
  /// Flutster floating button.
  Widget stopDisplayingFlutsterButton(
    BuildContext context,
    StateSetter setState,
  ) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      icon: const Icon(
        Icons.block,
        color: Colors.red,
      ),
      tooltip: "Stop displaying Flutster button",
      onPressed: () {
        confirmedAction(
          context: context,
          title: "Stop Flutster confirmation",
          message: "Stop displaying Flutster button until app restart",
          onOk: () async {
            testNameFieldController.text = "";
            widget.flutsterTestRecord.clear();
            closeTestRecordDialog();
            setState(() {
              displayFlutsterButton = false;
            });
          },
        );
      },
    ));
  }

  /// [takeScreenShotButton] builds a button to take a screenshot of the child
  /// widget.
  Widget takeScreenShotButton(BuildContext context, StateSetter setState,
      void Function(VoidCallback fn) updateParent) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      icon: Icon(
        Icons.camera,
        color:
            (!widget.flutsterTestRecord.recording) ? Colors.grey : Colors.blue,
      ),
      tooltip: "Take screenshot (also double-tap floating button)",
      onPressed: !widget.flutsterTestRecord.recording
          ? () {
              snack("Start recording to take screenshot", context);
            }
          : () async {
              await takeScreenShot(updateParent);
              setState(() {});
            },
    ));
  }

  /// [stopRecordingButton] builds a button to stop the recording.
  Widget stopRecordingButton(BuildContext context, StateSetter setState,
      void Function(VoidCallback fn) updateParent) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      // icon:const Icon(Icons.fiber_manual_record),
      icon: const Icon(
        Icons.circle,
      ),
      color: Colors.red,
      onPressed: () {
        if (!widget.flutsterTestRecord.recording) {
          return;
        }
        updateParent(() {
          widget.flutsterTestRecord.recording = false;
        });
        setState(() {});
        snack(const Text("Recording stopped"), context);
      },
      tooltip: "Stop recording",
    ));
  }

  /// [startRecordingButton] builds a button to start the recording.
  Widget startRecordingButton(BuildContext context, StateSetter setState,
      void Function(VoidCallback fn) updateParent) {
    return (IconButton(
      padding: const EdgeInsets.all(0.0),
      icon: const Icon(Icons.stop_circle_outlined),
      color: Colors.blue,
      onPressed: () {
        if (widget.flutsterTestRecord.recording) {
          return;
        }
        updateParent(() {
          widget.flutsterTestRecord.recording = true;
        });
        setState(() {});
        snack(Text(
          widget.flutsterTestRecord.events.isEmpty
              ? "Recording started"
              : "Recording resumed",
        ));
      },
      tooltip: widget.flutsterTestRecord.events.isEmpty
          ? "Start recording"
          : "Resume recording",
    ));
  }

  /// [closeTestRecordDialog] closes the test record dialog
  void closeTestRecordDialog() {
    Navigator.of(context).pop();
  }
}

/// [FlutsterScaffold] wraps a Scaffold within a [FlutsterTestRecorder].
class FlutsterScaffold extends StatelessWidget {
  /// [appBar] please refer to Scaffold.
  final PreferredSizeWidget? appBar;

  /// [body] please refer to Scaffold.
  final Widget? body;

  /// [floatingActionButton] please refer to Scaffold.
  final Widget? floatingActionButton;

  /// [floatingActionButtonLocation] please refer to Scaffold.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// [floatingActionButtonAnimator] please refer to Scaffold.
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;

  /// [persistentFooterButtons] please refer to Scaffold.
  final List<Widget>? persistentFooterButtons;

  /// [drawer] please refer to Scaffold.
  final Widget? drawer;

  /// [onDrawerChanged] please refer to Scaffold.
  final DrawerCallback? onDrawerChanged;

  /// [endDrawer] please refer to Scaffold.
  final Widget? endDrawer;

  /// [onEndDrawerChanged] please refer to Scaffold.
  final DrawerCallback? onEndDrawerChanged;

  /// [bottomNavigationBar] please refer to Scaffold.
  final Widget? bottomNavigationBar;

  /// [bottomSheet] please refer to Scaffold.
  final Widget? bottomSheet;

  /// [backgroundColor] please refer to Scaffold.
  final Color? backgroundColor;

  /// [resizeToAvoidBottomInset] please refer to Scaffold.
  final bool? resizeToAvoidBottomInset;

  /// [primary] please refer to Scaffold.
  final bool primary;

  /// [drawerDragStartBehavior] please refer to Scaffold.
  final DragStartBehavior drawerDragStartBehavior;

  /// [extendBody] please refer to Scaffold.
  final bool extendBody;

  /// [extendBodyBehindAppBar] please refer to Scaffold.
  final bool extendBodyBehindAppBar;

  /// [drawerScrimColor] please refer to Scaffold.
  final Color? drawerScrimColor;

  /// [drawerEdgeDragWidth] please refer to Scaffold.
  final double? drawerEdgeDragWidth;

  /// [drawerEnableOpenDragGesture] please refer to Scaffold.
  final bool drawerEnableOpenDragGesture;

  /// [endDrawerEnableOpenDragGesture] please refer to Scaffold.
  final bool endDrawerEnableOpenDragGesture;

  /// [restorationId] please refer to Scaffold.
  final String? restorationId;

  /// [flutsterTestRecord] if not given, the default is used.
  final FlutsterTestRecord? flutsterTestRecord;

  /// [name] helps identify the right [FlutsterTestRecorderState] while running.
  final String? name;

  /// [FlutsterScaffold] is a Scaffold with a name and a
  /// [flutsterTestRecord].
  FlutsterScaffold({
    Key? key,
    this.name,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.drawer,
    this.onDrawerChanged,
    this.endDrawer,
    this.onEndDrawerChanged,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.drawerDragStartBehavior = DragStartBehavior.start,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerScrimColor,
    this.drawerEdgeDragWidth,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    this.restorationId,
    this.flutsterTestRecord,
  }) : super(key: name == null ? null : Key("${name}Flutster"));

  /// [build] as with any widget.
  @override
  Widget build(BuildContext context) {
    if (!(flutsterTestRecord ?? FlutsterTestRecord.defaultRecord).active) {
      return (buildScaffold(context));
    }
    return (FlutsterTestRecorder(
      key: key ?? Key("${name ?? "fromScaffold"}FlutsterTestRecorder"),
      givenFlutsterTestRecord:
          flutsterTestRecord ?? FlutsterTestRecord.defaultRecord,
      name: name,
      child: buildScaffold(context),
    ));
  }

  /// [buildScaffold] returns the wrapped scaffold.
  Widget buildScaffold(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      drawer: drawer,
      onDrawerChanged: onDrawerChanged,
      endDrawer: endDrawer,
      onEndDrawerChanged: onEndDrawerChanged,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      drawerDragStartBehavior: drawerDragStartBehavior,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerScrimColor: drawerScrimColor,
      drawerEdgeDragWidth: drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
      restorationId: restorationId,
    );
  }
}
