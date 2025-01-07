// pubspec.yaml
// Añade estas dependencias:
// sensors_plus: ^1.4.1
// web_socket_channel: ^2.4.0

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GyroscopePage(),
    );
  }
}

class GyroscopePage extends StatefulWidget {
  @override
  _GyroscopePageState createState() => _GyroscopePageState();
}

class _GyroscopePageState extends State<GyroscopePage> {
  WebSocketChannel? channel;
  bool isConnected = false;
  String serverIp = '192.168.1.161'; // Cambia a la IP de tu servidor ROS2
  //String serverIp = '10.0.2.2'; // ip emulador de android studio
  String serverPort = '9090';

  @override
  void initState() {
    super.initState();
    connectToServer();
    startGyroscopeStream();
  }

  void connectToServer() {
    try {
      channel = WebSocketChannel.connect(
        Uri.parse('ws://$serverIp:$serverPort'),
      );
      setState(() {
        isConnected = true;
      });
    } catch (e) {
      print('Error connecting to server: $e');
      setState(() {
        isConnected = false;
      });
    }
  }

void startGyroscopeStream() {
  // Anuncia el tópico con el tipo correcto
  final advertiseMessage = {
    'op': 'advertise',
    'topic': '/iphone/gyro',
    'type': 'geometry_msgs/Twist'
  };
  channel!.sink.add(jsonEncode(advertiseMessage));

  // Publica datos del giroscopio
  gyroscopeEvents.listen((GyroscopeEvent event) {
    if (isConnected && channel != null) {
      final gyroData = {
        'op': 'publish',
        'topic': '/iphone/gyro',
        'msg': {
          'linear': {'x': 0.0, 'y': 0.0, 'z': 0.0}, // Usamos 0 para los valores lineales
          'angular': {'x': event.x, 'y': event.y, 'z': event.z} // Valores del giroscopio
        }
      };
      channel!.sink.add(jsonEncode(gyroData));
    }
  });
}

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gyroscope to ROS2'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isConnected ? 'Connected to ROS2' : 'Disconnected',
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.red,
                fontSize: 20,
              ),
            ),
            StreamBuilder<GyroscopeEvent>(
              stream: gyroscopeEvents,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('X: ${snapshot.data!.x.toStringAsFixed(3)}'),
                        Text('Y: ${snapshot.data!.y.toStringAsFixed(3)}'),
                        Text('Z: ${snapshot.data!.z.toStringAsFixed(3)}'),
                      ],
                    ),
                  );
                }
                return const CircularProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }
}