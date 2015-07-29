library updroid_console;

import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:terminal/terminal.dart';
import 'package:terminal/theme.dart';

import 'package:upcom-api/web/mailbox/mailbox.dart';
import 'package:upcom-api/web/tab/tab_controller.dart';

/// [UpDroidConsole] is a client-side class that combines a [Terminal]
/// and [WebSocket] into an UpDroid Commander tab.
class UpDroidConsole extends TabController {
  static final List<String> names = ['upcom-console', 'UpDroid Console', 'Console'];

  static List getMenuConfig() {
    List menu = [
      {'title': 'File', 'items': [
        {'type': 'toggle', 'title': 'Close Tab'}]},
      {'title': 'Settings', 'items': [
        {'type': 'toggle', 'title': 'Invert'},
        {'type': 'toggle', 'title': 'Cursor Blink'}]}
    ];
    return menu;
  }

  Terminal _term;

  AnchorElement _themeButton, _blinkButton;

  Timer _resizeTimer;

  UpDroidConsole() :
  super(UpDroidConsole.names, getMenuConfig(), 'tabs/upcom-console/console.css') {

  }

  void setUpController() {
    _themeButton = view.refMap['invert'];
    _blinkButton = view.refMap['cursor-blink'];

    _term = new Terminal(view.content)
      ..scrollSpeed = 3
      ..cursorBlink = true
      ..theme = customDarkTheme();
  }

  /// Toggles between a Solarized dark and light theme.
  void _toggleTheme() {
    _term.theme = _term.theme.name == 'updroid-light' ? customDarkTheme() : customLightTheme();
  }

  /// Toggles cursor blink on/off.
  void _toggleBlink() {
    _term.cursorBlink = _term.cursorBlink ? false : true;
  }

  void _startPty(Msg um) {
    List<int> size = _term.calculateSize();
    _term.resize(size[0], size[1]);
    mailbox.ws.send('[[START_PTY]]${size[0]}x${size[1] - 1}');
  }

  void _handleData(Msg um) => _term.stdout.add(JSON.decode(um.body));

  /// Handle an incoming resize event, originating from either this [UpDroidConsole] or another.
  void _resizeHandler(Msg um) {
    List newSize = um.body.split('x');
    int newRow = int.parse(newSize[0]);
    int newCol = int.parse(newSize[1]);
    _term.resize(newRow, newCol);
  }

  Theme customDarkTheme() {
    String name = 'updroid-dark';
    Map<String, String> colors = {
      'black'   : '#1c1c1c',
      'red'     : '#ff2919',
      'green'   : '#ff2919',
      'yellow'  : '#ff2919',
      'blue'    : '#eaecec',
      'magenta' : '#eaecec',
      'cyan'    : '#eaecec',
      'white'   : '#ffffff'
    };

    String foregroundColor = colors['white'];
    String backgroundColor = colors['black'];

    return new Theme(name, colors, foregroundColor, backgroundColor);
  }

  Theme customLightTheme() {
    String name = 'updroid-light';
    Map<String, String> colors = {
      'black'   : '#eaecec',
      'red'     : '#ff2919',
      'green'   : '#ff2919',
      'yellow'  : '#ff2919',
      'blue'    : '#7e7e7e',
      'magenta' : '#7e7e7e',
      'cyan'    : '#7e7e7e',
      'white'   : '#1e1e1e'
    };

    String foregroundColor = colors['white'];
    String backgroundColor = colors['black'];

    return new Theme(name, colors, foregroundColor, backgroundColor);
  }

  //\/\/ Mailbox Handlers /\/\//

  void registerMailbox() {
    mailbox.registerWebSocketEvent(EventType.ON_OPEN, 'TAB_READY', _startPty);
    mailbox.registerWebSocketEvent(EventType.ON_MESSAGE, 'RESIZE', _resizeHandler);
    mailbox.registerWebSocketEvent(EventType.ON_MESSAGE, 'DATA', _handleData);
  }

  /// Sets up the event handlers for the console.
  void registerEventHandlers() {
    _term.stdin.stream.listen((data) => mailbox.ws.send('[[DATA]]' + JSON.encode(data)));

    _themeButton.onClick.listen((e) {
      _toggleTheme();
      e.preventDefault();
    });

    _blinkButton.onClick.listen((e) {
      _toggleBlink();
      e.preventDefault();
    });

    window.onResize.listen((e) {
      if (view.content.parent.parent.classes.contains('active')) {
        // Timer prevents a flood of resize events slowing down the system and allows the window to settle.
        if (_resizeTimer != null) _resizeTimer.cancel();
        _resizeTimer = new Timer(new Duration(milliseconds: 500), () {
          List<int> newSize = _term.calculateSize();
          mailbox.ws.send('[[INITIATE_RESIZE]]' + '${newSize[0]}x${newSize[1]}');
        });
      }
    });
  }

  Element get elementToFocus => view.content.children[0];

  Future<bool> preClose() {
    Completer c = new Completer();
    c.complete(true);
    return c.future;
  }

  void cleanUp() {

  }
}