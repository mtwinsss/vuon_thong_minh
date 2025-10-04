import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Garden Dashboard',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ====== Dữ liệu cảm biến ======
  double temperature = 0;
  double humidity = 0;
  double soilHumidity = 0;
  String soilStatus = "Đang đo...";

  bool ledOn = false;
  bool pumpOn = false;
  bool servoOn = false;

  List<FlSpot> tempHistory = [];
  List<FlSpot> humHistory = [];
  Timer? updateTimer;
  Timer? historyTimer;
  int timeIndex = 0;

  late IO.Socket socket;

  static const String SERVER_URL = "http://192.168.1.10:3000"; // ⚠️ Đổi IP cho đúng

  @override
  void initState() {
    super.initState();
    connectToServer();

    // Giả lập dữ liệu cảm biến mỗi 2 giây
    updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        temperature = 20 + Random().nextDouble() * 10; // 20–30 °C
        humidity = 50 + Random().nextDouble() * 20; // 50–70 %
        soilHumidity = Random().nextDouble() * 100; // 0–100 %
        soilStatus = getSoilStatus(soilHumidity);
      });
    });

    // Ghi lại lịch sử mỗi 5 phút
    historyTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      setState(() {
        tempHistory.add(FlSpot(timeIndex.toDouble(), temperature));
        humHistory.add(FlSpot(timeIndex.toDouble(), humidity));
        timeIndex++;
      });
    });
  }

  @override
  void dispose() {
    socket.dispose();
    updateTimer?.cancel();
    historyTimer?.cancel();
    super.dispose();
  }

  // ====== Kết nối socket ======
  void connectToServer() {
    socket = IO.io(
      SERVER_URL,
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    socket.connect();

    socket.onConnect((_) => debugPrint("✅ Connected to server"));
    socket.onDisconnect((_) => debugPrint("❌ Disconnected"));

    socket.on("sensor_update", (data) {
      if (data != null) {
        setState(() {
          temperature = (data['temperature'] ?? 0).toDouble();
          humidity = (data['humidity'] ?? 0).toDouble();
          soilHumidity = (data['soil'] ?? Random().nextDouble() * 100).toDouble();
          soilStatus = getSoilStatus(soilHumidity);
        });
      }
    });
  }

  // ====== Gửi lệnh điều khiển ======
  void sendControl(String device, bool state) {
    socket.emit("controlDevice", {"device": device, "state": state});
    debugPrint("📤 Sent control → $device: $state");
  }

  // ====== Hàm xác định trạng thái độ ẩm đất ======
  String getSoilStatus(double soil) {
    if (soil < 30) return "🌵 Quá khô";
    if (soil < 70) return "🌿 Bình thường";
    return "💧 Quá ẩm";
  }

  // ====== UI ======
  Widget buildDeviceControl(String name, bool state, Function(bool) onChanged) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        trailing: Switch(
          value: state,
          onChanged: (val) {
            setState(() => onChanged(val));
          },
        ),
      ),
    );
  }

  Widget buildChart(List<FlSpot> data, String label, Color color) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: const FlTitlesData(show: true),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: data,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 150,
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Garden Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hiển thị số liệu cảm biến
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSensorCard("🌡 Nhiệt độ", "${temperature.toStringAsFixed(1)} °C", Colors.red),
                _buildSensorCard("💧 Độ ẩm", "${humidity.toStringAsFixed(1)} %", Colors.blue),
              ],
            ),
            const SizedBox(height: 20),

            // Thẻ hiển thị độ ẩm đất
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  children: [
                    const Text("🌱 Độ ẩm đất", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("${soilHumidity.toStringAsFixed(1)} %",
                        style: const TextStyle(fontSize: 20, color: Colors.brown, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(soilStatus,
                        style: TextStyle(
                            fontSize: 18,
                            color: soilStatus.contains("Quá khô")
                                ? Colors.red
                                : soilStatus.contains("Bình thường")
                                ? Colors.green
                                : Colors.blue)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Điều khiển thiết bị
            buildDeviceControl("Đèn LED", ledOn, (val) {
              ledOn = val;
              sendControl("led", val);
            }),
            buildDeviceControl("Máy bơm", pumpOn, (val) {
              pumpOn = val;
              sendControl("pump", val);
            }),
            buildDeviceControl("Mái che", servoOn, (val) {
              servoOn = val;
              sendControl("servo", val);
            }),

            const SizedBox(height: 20),

            // Biểu đồ lịch sử
            const Text("Lịch sử nhiệt độ & độ ẩm (5 phút/lần)",
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            if (tempHistory.isNotEmpty)
              buildChart(tempHistory, "Temperature", Colors.red),
            if (humHistory.isNotEmpty)
              buildChart(humHistory, "Humidity", Colors.blue),
          ],
        ),
      ),
    );
  }
}
