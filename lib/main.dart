import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
  double temperature = 0;
  double humidity = 0;
  bool ledOn = false;
  bool pumpOn = false;
  bool servoOn = false;

  List<FlSpot> tempHistory = [];
  List<FlSpot> humHistory = [];
  Timer? updateTimer;
  Timer? historyTimer;
  int timeIndex = 0;

  @override
  void initState() {
    super.initState();
    // Giả lập dữ liệu cảm biến mỗi 2 giây
    updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        temperature = 20 + Random().nextDouble() * 10; // 20-30 °C
        humidity = 50 + Random().nextDouble() * 20;    // 50-70 %
      });
    });

    // Ghi lại dữ liệu mỗi 5 phút
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
    updateTimer?.cancel();
    historyTimer?.cancel();
    super.dispose();
  }

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

            // Nút điều khiển thiết bị
            buildDeviceControl("Đèn LED", ledOn, (val) => ledOn = val),
            buildDeviceControl("Máy bơm", pumpOn, (val) => pumpOn = val),
            buildDeviceControl("Servo", servoOn, (val) => servoOn = val),

            const SizedBox(height: 20),

            // Biểu đồ lịch sử
            const Text("Lịch sử nhiệt độ & độ ẩm (5 phút/lần)", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            if (tempHistory.isNotEmpty) buildChart(tempHistory, "Temperature", Colors.red),
            if (humHistory.isNotEmpty) buildChart(humHistory, "Humidity", Colors.blue),
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
}
