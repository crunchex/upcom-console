library cmdr_console;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:upcom-api/tab.dart';
import 'package:upcom-api/updroid_message.dart';
import 'package:upcom-api/server_message.dart';
import 'package:upcom-api/server_helper.dart' as help;

class CmdrConsole extends Tab {
  Process _shell;
  String _workspacePath;
  Socket _ptySocket;

  CmdrConsole(int id, String workspacePath, SendPort sp, List args) :
  super(id, 'UpDroidConsole', sp) {
    _workspacePath = workspacePath;
    mailbox.send(new Msg('TAB_READY'));
  }

  void registerMailbox() {
    mailbox.registerMessageHandler('START_PTY', _startPty);
    mailbox.registerMessageHandler('INITIATE_RESIZE', _resizeRelay);
    mailbox.registerMessageHandler('RESIZE', _resizeHandle);
    mailbox.registerMessageHandler('DATA', _handleIOStream);
  }

  void _startPty(String msg) {
    // Process launches 'cmdr-pty', a go program that provides a direct hook to a system pty.
    // See http://bitbucket.org/updroid/cmdr-pty
    Process.start('cmdr-pty', ['-p', 'tcp', '-s', msg], environment: {'TERM':'vt100'}, workingDirectory: _workspacePath).then((Process shell) {
      _shell = shell;

      // Get the port returned by cmdr-pty and then close.
      StreamSubscription portListener;
      portListener = shell.stdout.listen((data) {
        String dataString = UTF8.decode(data);
        if (dataString.contains('listening on port: ')) {
          String port = dataString.replaceFirst('listening on port: ', '');
          portListener.cancel();

          Socket.connect('127.0.0.1', int.parse(port)).then((socket) {
            _ptySocket = socket;
            socket.listen((data) => mailbox.send(new Msg('DATA', JSON.encode(data))));
          });
        }
      });

      // Log the rest of stdout/err for debug.
//      stdoutBroadcast.listen((data) => print('pty[$id] stdout: ${UTF8.decode(data)}'));
//      shell.stderr.listen((data) => print('pty[$id] stderr: ${UTF8.decode(data)}'));
    }).catchError((error) {
      if (error is! ProcessException) throw error;
      help.debug('cmdr-pty [$id]: run failed. Probably not installed', 1);
      return;
    });
  }

  void _handleIOStream(String msg) {
    if (_ptySocket != null) _ptySocket.add(JSON.decode(msg));
  }

  void _resizeRelay(String msg) {
    Msg m = new Msg('RESIZE', msg);
    mailbox.relay(new ServerMessage('UpDroidConsole', 0, m));
  }

  void _resizeHandle(String msg) {
    // Resize the shell.
    List newSize = msg.split('x');
    int newRow = int.parse(newSize[0]);
    int newCol = int.parse(newSize[1]) - 1;
    _shell.stdin.writeln('${newRow}x${newCol}');
    // Send the new size to all UpDroidConsoles (including this one) to be relayed
    // back to their client side.
    mailbox.send(new Msg('RESIZE', msg));
  }

  void cleanup() {
    if (_ptySocket != null) _ptySocket.destroy();
    if (_shell != null) _shell.kill();
  }
}