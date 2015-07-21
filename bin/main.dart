import 'dart:isolate';
import 'package:upcom-api/tab.dart';
import '../lib/pty.dart';

void main(List args, SendPort interfacesSendPort) {
  Tab.main(interfacesSendPort, args, (id, path, port, args) => new CmdrConsole(id, path, port, args));
}