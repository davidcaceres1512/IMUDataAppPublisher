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
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        textTheme: Typography.blackCupertino,
      ),
      home: IpInputScreen(),
    );
  }
}

class IpInputScreen extends StatefulWidget {
  @override
  _IpInputScreenState createState() => _IpInputScreenState();
}

class _IpInputScreenState extends State<IpInputScreen> {
  final TextEditingController _ipController = TextEditingController();
  String connectionStatus = "OFF";
  WebSocketChannel? channel;
  bool isWaitingForAck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBridgeCheckPopup());
  }

  Future<void> _showBridgeCheckPopup() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Aviso', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('¿Ya ejecutaste el bridge en ROS2?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK', style: TextStyle(color: Colors.indigo)),
            ),
          ],
        );
      },
    );
  }

  Future<void> connectToServer(String ip, String port) async {
    if (channel != null) {
      await channel!.sink.close();
      channel = null;
    }

    setState(() {
      isWaitingForAck = true;
      connectionStatus = "CONNECTING...";
    });

    try {
      channel = WebSocketChannel.connect(
        Uri.parse('ws://$ip:$port'),
      );

      // Suscribirse al tópico de ACK
      final subscribeMessage = {
        'op': 'subscribe',
        'topic': '/bridge_status',
        'type': 'std_msgs/String'
      };

      // Publicar en el tópico de ACK request
      final ackRequestMessage = {
        'op': 'advertise',
        'topic': '/client_connection_request',
        'type': 'std_msgs/String'
      };

      channel?.sink.add(jsonEncode(subscribeMessage));
      channel?.sink.add(jsonEncode(ackRequestMessage));

      // Enviar mensaje de solicitud de conexión
      final connectionRequest = {
        'op': 'publish',
        'topic': '/client_connection_request',
        'msg': {
          'data': 'CONNECTION_REQUEST'
        }
      };
      
      channel?.sink.add(jsonEncode(connectionRequest));

      // Timer para timeout de conexión
      Future.delayed(Duration(seconds: 5), () {
        if (isWaitingForAck) {
          setState(() {
            connectionStatus = "OFF";
            isWaitingForAck = false;
          });
          _showConnectionTimeoutDialog();
        }
      });

      channel?.stream.listen((message) {
        final data = jsonDecode(message);
        print('Mensaje recibido: $data');
        
        // Verificar si es un mensaje del tópico bridge_status
        if (data['topic'] == '/bridge_status' && data['msg']['data'] == 'CONNECTION_ACK') {
          setState(() {
            connectionStatus = "ON";
            isWaitingForAck = false;
          });
        }
      }, onError: (error) {
        print('Error during connection: $error');
        setState(() {
          connectionStatus = "OFF";
          isWaitingForAck = false;
        });
      }, onDone: () {
        print('Connection closed.');
        setState(() {
          connectionStatus = "OFF";
          isWaitingForAck = false;
        });
      });
    } catch (e) {
      print('Error connecting to server: $e');
      setState(() {
        connectionStatus = "OFF";
        isWaitingForAck = false;
      });
    }
  }

  Future<void> _showConnectionTimeoutDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Error de Conexión', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('No se recibió respuesta del servidor ROS2. Verifica que el bridge esté ejecutándose correctamente.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK', style: TextStyle(color: Colors.indigo)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurar IP del Servidor', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade100, Colors.indigo.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'IP del Servidor',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.wifi, color: Colors.indigo),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isWaitingForAck ? null : () {
                final ip = _ipController.text;
                if (ip.isNotEmpty) {
                  connectToServer(ip, '9090');
                }
              },
              child: Text(
                isWaitingForAck ? 'Conectando...' : 'Conectar',
                style: TextStyle(fontSize: 16)
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text('Estado de Conexión:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  SizedBox(height: 10),
                  Text(
                    connectionStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: connectionStatus == "ON" 
                          ? Colors.green 
                          : connectionStatus == "CONNECTING..." 
                              ? Colors.orange 
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: connectionStatus == "ON" ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GyroscopePage(channel: channel),
                  ),
                );
              } : null,
              child: Text('Continuar a la App', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class GyroscopePage extends StatefulWidget {
  final WebSocketChannel? channel;

  GyroscopePage({required this.channel});

  @override
  _GyroscopePageState createState() => _GyroscopePageState();
}

class _GyroscopePageState extends State<GyroscopePage> {
  bool isTakeoffPressed = false;
  AccelerometerEvent? lastAccelerometerEvent;

  @override
  void initState() {
    super.initState();
    startSensorStreams();
    startCommandPublisher();
  }

  void startCommandPublisher() {
    final advertiseMessage = {
      'op': 'advertise',
      'topic': '/drone/commands',
      'type': 'std_msgs/String'
    };
    widget.channel?.sink.add(jsonEncode(advertiseMessage));
  }

  void startSensorStreams() {
    final advertiseMessage = {
      'op': 'advertise',
      'topic': '/iphone/gyro_accel',
      'type': 'geometry_msgs/Twist'
    };
    widget.channel?.sink.add(jsonEncode(advertiseMessage));

    accelerometerEvents.listen((AccelerometerEvent event) {
      lastAccelerometerEvent = event;
    });

    gyroscopeEvents.listen((GyroscopeEvent event) {
      if (widget.channel != null && lastAccelerometerEvent != null) {
        final sensorData = {
          'op': 'publish',
          'topic': '/iphone/gyro_accel',
          'msg': {
            'linear': {
              'x': lastAccelerometerEvent!.x,
              'y': lastAccelerometerEvent!.y,
              'z': lastAccelerometerEvent!.z
            },
            'angular': {'x': event.x, 'y': event.y, 'z': event.z}
          }
        };
        widget.channel?.sink.add(jsonEncode(sensorData));
      }
    });
  }

  void sendTakeoffStartCommand() {
    if (widget.channel != null) {
      final takeoffCommand = {
        'op': 'publish',
        'topic': '/drone/commands',
        'msg': {
          'data': 'TAKEOFF_START'
        }
      };
      widget.channel?.sink.add(jsonEncode(takeoffCommand));
    }
  }

  void sendTakeoffStopCommand() {
    if (widget.channel != null) {
      final takeoffCommand = {
        'op': 'publish',
        'topic': '/drone/commands',
        'msg': {
          'data': 'TAKEOFF_STOP'
        }
      };
      widget.channel?.sink.add(jsonEncode(takeoffCommand));
    }
  }

  void sendLandCommand() {
    if (widget.channel != null) {
      final landCommand = {
        'op': 'publish',
        'topic': '/drone/commands',
        'msg': {
          'data': 'LAND'
        }
      };
      widget.channel?.sink.add(jsonEncode(landCommand));
    }
  }

  @override
  void dispose() {
    widget.channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gyroscope and Accelerometer to ROS2'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade100, Colors.indigo.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Takeoff (Hold)',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: sendLandCommand,
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
                          Text('Gyro X: ${snapshot.data!.x.toStringAsFixed(3)} rad/s', style: TextStyle(fontSize: 16)),
                          Text('Gyro Y: ${snapshot.data!.y.toStringAsFixed(3)} rad/s', style: TextStyle(fontSize: 16)),
                          Text('Gyro Z: ${snapshot.data!.z.toStringAsFixed(3)} rad/s', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }
                  return const CircularProgressIndicator();
                },
              ),
              StreamBuilder<AccelerometerEvent>(
                stream: accelerometerEvents,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Accel X: ${snapshot.data!.x.toStringAsFixed(3)} m/s²', style: TextStyle(fontSize: 16)),
                          Text('Accel Y: ${snapshot.data!.y.toStringAsFixed(3)} m/s²', style: TextStyle(fontSize: 16)),
                          Text('Accel Z: ${snapshot.data!.z.toStringAsFixed(3)} m/s²', style: TextStyle(fontSize: 16)),
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
      ),
    );
  }
}