import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一鍵停車助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '一鍵停車助手'),
    );
  }
}

class ParkingRecord {
  final double latitude;
  final double longitude;
  final DateTime time;
  final Duration? duration;
  final String? address;
  final String? note;

  ParkingRecord({
    required this.latitude, 
    required this.longitude, 
    required this.time,
    this.duration,
    this.address,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'time': time.toIso8601String(),
    'duration': duration?.inSeconds,
    'address': address,
    'note': note,
  };

  factory ParkingRecord.fromJson(Map<String, dynamic> json) {
    return ParkingRecord(
      latitude: json['latitude'],
      longitude: json['longitude'],
      time: DateTime.parse(json['time']),
      duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
      address: json['address'] as String?,
      note: json['note'] as String?,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  DateTime? _parkingTime;
  Timer? _timer;
  Duration _elapsedDuration = Duration.zero;
  bool _isParkingCompleted = false;
  List<ParkingRecord> _history = [];
  final TextEditingController _noteController = TextEditingController();
  String? _currentNote;

  @override
  void initState() {
    super.initState();
    _loadParkingData();
    _startTimer();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _stopTimer();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onNoteChanged() async {
    if (_parkingTime != null && !_isParkingCompleted) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String note = _noteController.text.trim();
      setState(() {
        _currentNote = note.isNotEmpty ? note : null;
      });
      if (note.isNotEmpty) {
        await prefs.setString('parking_note', note);
      } else {
        await prefs.remove('parking_note');
      }
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isParkingCompleted) {
        _updateElapsedTime();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _loadParkingData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Load current parking status
    final String? timeStr = prefs.getString('parking_time');
    if (timeStr != null) {
      setState(() {
        _parkingTime = DateTime.parse(timeStr);
        _updateElapsedTime();
      });
    }
    
    // Load note
    final String? savedNote = prefs.getString('parking_note');
    if (savedNote != null) {
      _noteController.text = savedNote;
      setState(() {
        _currentNote = savedNote;
      });
    }

    // Load history
    final List<String>? historyJson = prefs.getStringList('parking_history');
    if (historyJson != null) {
      setState(() {
        _history = historyJson
            .map((e) => ParkingRecord.fromJson(jsonDecode(e)))
            .toList();
      });
    }
  }

  void _updateElapsedTime() {
    if (_parkingTime == null) return;
    
    setState(() {
      _elapsedDuration = DateTime.now().difference(_parkingTime!);
    });
  }

  Future<void> _saveLocation() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check/Request Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('需要位置權限才能記錄停車位置');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('位置權限已被永久拒絕，請至設定中開啟');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      // Get address from coordinates
      final String? address = await _getAddressFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      
      // Save to Shared Preferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latitude', position.latitude);
      await prefs.setDouble('longitude', position.longitude);
      if (address != null) {
        await prefs.setString('parking_address', address);
      }
      
      final DateTime now = DateTime.now();
      await prefs.setString('parking_time', now.toIso8601String());
      
      // Save initial note
      final String initialNote = _noteController.text.trim();
      if (initialNote.isNotEmpty) {
        await prefs.setString('parking_note', initialNote);
        setState(() {
          _currentNote = initialNote;
        });
      } else {
        await prefs.remove('parking_note');
        setState(() {
          _currentNote = null;
        });
      }
      


      setState(() {
        _parkingTime = now;
        _isParkingCompleted = false;
        _updateElapsedTime();
      });
      
      _startTimer();

      _showSnackBar('停車位置已儲存！\n時間: ${now.toString().substring(0, 16)}');

    } catch (e) {
      _showSnackBar('發生錯誤: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToCar() async {
    setState(() => _isLoading = true);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final double? lat = prefs.getDouble('latitude');
      final double? long = prefs.getDouble('longitude');
      final String? address = prefs.getString('parking_address');
      final String? note = prefs.getString('parking_note');

      if (lat == null || long == null) {
        _showSnackBar('尚未儲存停車位置！');
        return;
      }

      final Uri uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$long');
      
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnackBar('無法開啟地圖');
      } else {
        // Stop timer and mark as completed
        _stopTimer();

        // Calculate duration and save history
        if (_parkingTime != null) {
          final Duration duration = DateTime.now().difference(_parkingTime!);
          
          final newRecord = ParkingRecord(
            latitude: lat, 
            longitude: long, 
            time: _parkingTime!,
            duration: duration,
            address: address,
            note: note,
          );

          List<ParkingRecord> newHistory = List.from(_history);
          newHistory.insert(0, newRecord); // Add to top
          if (newHistory.length > 5) {
            newHistory.removeLast(); // Remove oldest if > 5
          }

          final List<String> historyJson = newHistory
              .map((e) => jsonEncode(e.toJson()))
              .toList();
          await prefs.setStringList('parking_history', historyJson);

          setState(() {
            _history = newHistory;
          });
        }

        await prefs.remove('parking_time');
        await prefs.remove('parking_address');
        await prefs.remove('parking_note');
        _noteController.clear();
        
        setState(() {
          _isParkingCompleted = true;
        });
      }

    } catch (e) {
      _showSnackBar('發生錯誤: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1'
        ),
        headers: {'User-Agent': 'CarLocatorApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addressDetails = data['address'] as Map<String, dynamic>?;
        
        if (addressDetails != null) {
          String formattedAddress = '';
          
          final postcode = addressDetails['postcode'] as String?;
          final city = addressDetails['city'] as String? ?? 
                      addressDetails['county'] as String? ?? 
                      addressDetails['state'] as String?;
          final district = addressDetails['suburb'] as String? ?? 
                         addressDetails['district'] as String? ?? 
                         addressDetails['neighbourhood'] as String?;
          final village = addressDetails['village'] as String? ?? 
                        addressDetails['hamlet'] as String?;
          final road = addressDetails['road'] as String? ?? 
                     addressDetails['street'] as String?;
          final houseNumber = addressDetails['house_number'] as String?;
          
          if (postcode != null) formattedAddress += postcode;
          if (city != null) formattedAddress += city;
          if (district != null) formattedAddress += district;
          if (village != null) formattedAddress += village;
          if (road != null) formattedAddress += road;
          if (houseNumber != null) formattedAddress += houseNumber;
          
          if (formattedAddress.isNotEmpty) {
            return formattedAddress;
          }
        }
        
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          return _formatTaiwanAddress(displayName);
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  String _formatTaiwanAddress(String address) {
    String result = address;
    
    result = result.replaceAll('臺灣', '').replaceAll('台灣', '');
    result = result.replaceAll(',', '').replaceAll('，', '');
    result = result.trim();
    
    return result;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/car_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (_parkingTime != null) ...[
                          Card(
                            margin: const EdgeInsets.all(16.0),
                            color: Colors.black.withOpacity(0.6),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    '上次停車時間：${_parkingTime.toString().substring(0, 16)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: _isParkingCompleted 
                                              ? '已完成: ${_elapsedDuration.inMinutes} 分鐘' 
                                              : '已停: ${_elapsedDuration.inMinutes} 分鐘',
                                          style: TextStyle(
                                            fontSize: 20, 
                                            color: _isParkingCompleted ? Colors.greenAccent : Colors.redAccent
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' ${(_elapsedDuration.inSeconds % 60).toString().padLeft(2, '0')} 秒',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _buildBigButton(
                          icon: Icons.local_parking,
                          label: '記下停車位置',
                          color: Colors.blue,
                          onPressed: _saveLocation,
                        ),
                        const SizedBox(height: 30),
                        _buildBigButton(
                          icon: Icons.directions_car,
                          label: '帶我去取車',
                          color: Colors.green,
                          onPressed: _navigateToCar,
                        ),
                        
                        const SizedBox(height: 30),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: TextField(
                            controller: _noteController,
                            maxLength: 30,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: '輸入備註:3樓115車格(最多30個字)',
                              hintStyle: const TextStyle(color: Colors.white54),
                              counterStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        if (_history.isNotEmpty) ...[
                          const Divider(color: Colors.grey),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              '最近 5 次紀錄',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              final record = _history[index];
                              final duration = record.duration;
                              String durationStr = '';
                              if (duration != null) {
                                final int hours = duration.inHours;
                                final int minutes = duration.inMinutes % 60;
                                final int seconds = duration.inSeconds % 60;
                                if (hours > 0) {
                                  durationStr = '$hours 小時 $minutes 分 $seconds 秒';
                                } else {
                                  durationStr = '$minutes 分 $seconds 秒';
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Card(
                                  color: Colors.black.withOpacity(0.4),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.history, color: Colors.white70),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    record.time.toString().substring(0, 16),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (record.address != null)
                                                    Text(
                                                      record.address!,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  Text(
                                                    '緯度: ${record.latitude.toStringAsFixed(4)}, 經度: ${record.longitude.toStringAsFixed(4)}',
                                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                  ),
                                                  if (duration != null)
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          const TextSpan(
                                                            text: '總停留: ',
                                                            style: TextStyle(color: Colors.white70, fontSize: 12),
                                                          ),
                                                          TextSpan(
                                                            text: durationStr,
                                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (record.note != null && record.note!.isNotEmpty)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            constraints: const BoxConstraints(
                                              maxWidth: 150,
                                            ),
                                            child: Text(
                                              record.note!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBigButton({
    required IconData icon, 
    required String label, 
    required Color color, 
    required VoidCallback onPressed
  }) {
    return SizedBox(
      width: 250,
      height: 100,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.85),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 40),
        label: Text(label, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
