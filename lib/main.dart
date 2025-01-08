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
  bool isTakeoffPressed = false;
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
        Uri.parse('wss://$serverIp:$serverPort'),
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
            'linear': {'x': 0.0, 'y': 0.0, 'z': 0.0},
            'angular': {'x': event.x, 'y': event.y, 'z': event.z}
          }
        };
        channel!.sink.add(jsonEncode(gyroData));
      }
    });
  }

  void sendTakeoffStartCommand() {
    if (isConnected && channel != null) {
      final takeoffCommand = {
        'op': 'publish',
        'topic': '/drone/control',
        'msg': {'data': 'takeoff_start'}
      };
      channel!.sink.add(jsonEncode(takeoffCommand));
    }
  }

  void sendTakeoffStopCommand() {
    if (isConnected && channel != null) {
      final takeoffCommand = {
        'op': 'publish',
        'topic': '/drone/control',
        'msg': {'data': 'takeoff_stop'}
      };
      channel!.sink.add(jsonEncode(takeoffCommand));
    }
  }

  void sendLandCommand() {
    if (isConnected && channel != null) {
      final landCommand = {
        'op': 'publish',
        'topic': '/drone/control',
        'msg': {'data': 'land'}
      };
      channel!.sink.add(jsonEncode(landCommand));
    }
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
            const SizedBox(height: 16),
            GestureDetector(
              onLongPressStart: (_) {
                setState(() => isTakeoffPressed = true);
                sendTakeoffStartCommand();
              },
              onLongPressEnd: (_) {
                setState(() => isTakeoffPressed = false);
                sendTakeoffStopCommand();
              },
              child: ElevatedButton(
                onPressed: () {}, // Esto mantiene el botón activo
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTakeoffPressed ? Colors.blue[700] : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Takeoff (Hold)',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: sendLandCommand,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Land',
                style: TextStyle(fontSize: 16),
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