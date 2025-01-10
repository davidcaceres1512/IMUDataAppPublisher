# flutter_application_1

Este proyecto Flutter forma parte del proyecto de fin de curso "Sistemas de Percepción" de la UMH. Está diseñado como una extensión del [proyecto UAV-LeaderFollower](https://github.com/davidcaceres1512/UAV-LeaderFollower), que implementa un esquema líder-seguidor para drones utilizando ROS 2 e Ignition Gazebo.

El objetivo principal de esta aplicación móvil es agregar una nueva funcionalidad al proyecto existente, permitiendo el control de los drones mediante una interfaz móvil. La app se encarga de enviar datos de un IMU (Unidad de Medición Inercial) y comandos de control (despegue, aterrizaje, etc.) al sistema ROS 2, brindando una forma más versátil e intuitiva de interactuar con el esquema líder-seguidor.

El proyecto UAV-LeaderFollower, desarrollado para el curso "Sistemas de Percepción en Robótica" de la Universidad Miguel Hernández (UMH), simula un sistema de control líder-seguidor para drones. Este incluye nodos para la generación de trayectorias, coordinación de movimiento entre los UAVs y visualización en Rviz. Con esta aplicación móvil, se busca complementar dicha funcionalidad, ofreciendo un control directo y en tiempo real desde un dispositivo móvil.

---

## Características

- Publicación de datos del giroscopio a un tópico ROS2 (`/iphone/gyro`).
- Envío de comandos al dron (`TAKEOFF_START`, `TAKEOFF_STOP`, `LAND`) al tópico `/drone/commands`.
- Conexión en tiempo real a un servidor ROS2 utilizando WebSocket.

---

## Prerrequisitos

### Configuración de Red

Debido a que la aplicación utiliza HTTP sin certificado SSL, funciona únicamente en una red local. Sigue estos pasos para garantizar una conexión adecuada:

#### Configuración de ROS2 y `rosbridge_server` en WSL

1. **Instalar ROS2 Humble**:
   Sigue la [documentación oficial de ROS2](https://docs.ros.org/en/humble/index.html) para instalarlo en WSL.

2. **Instalar `rosbridge_server`**:
   ```bash
   sudo apt install ros-humble-rosbridge-server
   ```

3. **Configurar el reenvío de puertos en Windows**:
   Ejecuta en PowerShell como administrador:
   ```powershell
   netsh interface portproxy add v4tov4 listenaddress=<IP_LOCAL> listenport=9090 connectaddress=<IP_WSL> connectport=9090
   ```
   Ejemplo:
   ```powershell
   netsh interface portproxy add v4tov4 listenaddress=192.168.1.161 listenport=9090 connectaddress=192.168.122.100 connectport=9090
   ```

4. **Verificar configuración del reenvío**:
   ```powershell
   netsh interface portproxy show all
   ```
   Debería mostrar:
   ```
   Listen on IPv4:             Connect to IPv4:
   Address         Port        Address         Port
   ----------------------------------------------
   192.168.1.161   9090        192.168.122.100 9090
   ```

5. **Configurar Firewall de Windows**:
   - Abre el puerto 9090 en el Firewall.
   - Asegúrate de que la regla permite conexiones para los perfiles de red actuales (Dominio, Privado, Público).

6. **Iniciar `rosbridge_server`**:
   Ejecuta en WSL:
   ```bash
   source /opt/ros/humble/setup.bash
   ros2 launch rosbridge_server rosbridge_websocket_launch.xml
   ```

7. **Probar conexión desde Windows**:
   ```powershell
   curl http://192.168.1.161:9090
   ```

---

## Compilación del Proyecto Flutter

1. **Instalar dependencias**:
   ```bash
   flutter pub get
   ```

2. **Verificar el entorno de Flutter**:
   ```bash
   flutter doctor
   ```

3. **Aceptar licencias de Android**:
   ```bash
   flutter doctor --android-licenses
   ```

4. **Compilar el proyecto**:
   ```bash
   flutter build apk --release
   ```

5. **Instalar la APK en un dispositivo**:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

---

## Configuración del Script Python para ROS2

### Script

```python
#!/usr/bin/env python3

import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from geometry_msgs.msg import Twist

class DroneCommandSubscriber(Node):
    def __init__(self):
        super().__init__('drone_command_and_gyro_subscriber')

        # Suscriptor para comandos del dron
        self.command_subscription = self.create_subscription(
            String,
            '/drone/commands',  # Tópico para comandos
            self.command_callback,
            10)
        self.get_logger().info('Drone command subscriber started')

        # Suscriptor para datos del giroscopio
        self.gyro_subscription = self.create_subscription(
            Twist,
            '/iphone/gyro',  # Tópico para datos del giroscopio
            self.gyro_callback,
            10)
        self.get_logger().info('Gyroscope data subscriber started')

    def command_callback(self, msg):
        """Procesa los comandos recibidos para el dron."""
        self.get_logger().info(f'Received command: {msg.data}')

    def gyro_callback(self, msg):
        """Procesa los datos del giroscopio."""
        self.get_logger().info(f'Received gyroscope data: Linear: {msg.linear}, Angular: {msg.angular}')

def main(args=None):
    rclpy.init(args=args)
    node = DroneCommandSubscriber()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
```

### Configuración

1. Coloca el script en el directorio `src` de tu paquete ROS2.
2. Hazlo ejecutable:
   ```bash
   chmod +x <nombre_del_archivo>.py
   ```

3. Ejecuta el nodo:
   ```bash
   ros2 run <nombre_del_paquete> <nombre_del_archivo>
   ```

---

## Despliegue y Demostración

### Pasos para probar la aplicación:

1. Instala la APK generada en un dispositivo Android o emulador.
2. Conecta el dispositivo a la misma red local que el servidor ROS2.
3. Asegúrate de que el servidor ROS2 y `rosbridge_server` estén corriendo correctamente.
4. Abre la aplicación y verifica:
   - Conexión con ROS2.
   - Publicación de datos del giroscopio.
   - Envío de comandos al dron.

### Screenshots


---

## Troubleshooting

1. **El puerto 9090 no responde**:
   - Verifica que el reenvío de puertos esté configurado.
   - Asegúrate de que el Firewall de Windows permite el puerto 9090.

2. **El servidor `rosbridge_server` no se ejecuta**:
   - Revisa que esté instalado correctamente.
   - Asegúrate de haber sourceado el entorno de ROS2 antes de ejecutarlo.

3. **El dispositivo no se conecta al servidor**:
   - Verifica que el dispositivo y el servidor están en la misma red.
   - Asegúrate de usar la IP correcta del servidor.
