import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'parking_model.dart';

class TdxService {
  static final TdxService _instance = TdxService._internal();
  factory TdxService() => _instance;
  TdxService._internal();

  Future<void> init() async {
    print('[TDX] 服務初始化完成 (訪客模式)');
  }

  Future<List<CarPark>> fetchOffStreetParking({double? userLat, double? userLon}) async {
    print('[TDX] ==================== 路外停車開始 ====================');
    print('[TDX] 使用者座標傳入: lat=$userLat, lon=$userLon');
    
    List<CarPark> carParks = [];
    
    try {
      String url = 'https://tdx.transportdata.tw/api/basic/v1/Parking/OffStreet/CarPark/City/Taipei?\$format=JSON';
      print('[TDX] 路外停車 API URL: $url');

      final response = await http.get(Uri.parse(url));
      print('[TDX] 路外停車狀態碼: ${response.statusCode}');
      print('[TDX] 路外停車 Response 長度: ${response.body.length}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final List<dynamic>? data = jsonData['CarParks'] as List?;
        if (data != null) {
          print('[TDX] 路外停車原始資料筆數: ${data.length}');
          carParks = data.map((item) => _parseOffStreetCarPark(item)).toList();
        } else {
          print('[TDX] 警告：路外停車找不到 CarParks 欄位');
        }
      }
      
      carParks = carParks.where((park) => park.lat != 0.0 && park.lon != 0.0).toList();
      print('[TDX] 有效資料筆數: ${carParks.length}');
      
      if (userLat != null && userLon != null) {
        print('[TDX] 開始依距離排序...');
        carParks = _sortByDistance(carParks, userLat, userLon);
        carParks = carParks.take(10).toList();
        print('[TDX] 已顯示距離最近的 10 個停車場');
      }
      
      print('[TDX] 最終回傳筆數: ${carParks.length}');
      return carParks;
    } catch (e) {
      print('[TDX] 路外停車資料抓取異常: $e');
      return carParks;
    }
  }
  
  Future<List<CarPark>> fetchOnStreetParking({double? userLat, double? userLon}) async {
    print('[TDX] ==================== 路邊停車開始 ====================');
    print('[TDX] 使用者座標傳入: lat=$userLat, lon=$userLon');
    
    List<CarPark> carParks = [];
    
    try {
      String url = 'https://tdx.transportdata.tw/api/basic/v1/Parking/OnStreet/ParkingSegment/City/Taipei?\$format=JSON';
      print('[TDX] 路邊停車 API URL: $url');

      final response = await http.get(Uri.parse(url));
      print('[TDX] 路邊停車狀態碼: ${response.statusCode}');
      print('[TDX] 路邊停車 Response 長度: ${response.body.length}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final List<dynamic>? data = jsonData['ParkingSegments'] as List?;
        if (data != null) {
          print('[TDX] 路邊停車原始資料筆數: ${data.length}');
          carParks = data.map((item) => _parseParkingSegment(item)).toList();
        } else {
          print('[TDX] 警告：路邊停車找不到 ParkingSegments 欄位');
        }
      }
      
      carParks = carParks.where((park) => park.lat != 0.0 && park.lon != 0.0).toList();
      print('[TDX] 有效資料筆數: ${carParks.length}');
      
      if (userLat != null && userLon != null) {
        print('[TDX] 開始依距離排序...');
        carParks = _sortByDistance(carParks, userLat, userLon);
        carParks = carParks.take(10).toList();
        print('[TDX] 已顯示距離最近的 10 個停車場');
      }
      
      print('[TDX] 最終回傳筆數: ${carParks.length}');
      return carParks;
    } catch (e) {
      print('[TDX] 路邊停車資料抓取異常: $e');
      return carParks;
    }
  }
  
  CarPark _parseParkingSegment(Map<String, dynamic> json) {
    String name = '';
    if (json['ParkingSegmentName'] != null && json['ParkingSegmentName']['Zh_tw'] != null) {
      name = json['ParkingSegmentName']['Zh_tw'];
    } else if (json['RoadSection'] != null && json['RoadSection']['RoadName'] != null && json['RoadSection']['RoadName']['Zh_tw'] != null) {
      name = json['RoadSection']['RoadName']['Zh_tw'];
    } else if (json['RoadName'] != null && json['RoadName']['Zh_tw'] != null) {
      name = json['RoadName']['Zh_tw'];
    } else if (json['SegmentID'] != null) {
      name = '路段 ${json['SegmentID']}';
    } else {
      name = '路邊停車';
    }
    
    double lat = 0.0;
    double lon = 0.0;
    
    if (json['ParkingSegmentPosition'] != null) {
      lat = _safeParseDouble(json['ParkingSegmentPosition']['PositionLat']);
      lon = _safeParseDouble(json['ParkingSegmentPosition']['PositionLon']);
    } else if (json['SegmentPosition'] != null) {
      lat = _safeParseDouble(json['SegmentPosition']['PositionLat']);
      lon = _safeParseDouble(json['SegmentPosition']['PositionLon']);
    } else if (json['PositionLat'] != null) {
      lat = _safeParseDouble(json['PositionLat']);
      lon = _safeParseDouble(json['PositionLon']);
    } else if (json['Position'] != null) {
      lat = _safeParseDouble(json['Position']['PositionLat']);
      lon = _safeParseDouble(json['Position']['PositionLon']);
    }
    
    String address = '';
    if (json['RoadSection'] != null && json['RoadSection']['RoadName'] != null && json['RoadSection']['RoadName']['Zh_tw'] != null) {
      address = json['RoadSection']['RoadName']['Zh_tw'];
    } else if (json['RoadName'] != null && json['RoadName']['Zh_tw'] != null) {
      address = json['RoadName']['Zh_tw'];
    }
    
    String fareDesc = json['FareDescription'] ?? '暫無費率資訊';
    String desc = json['Description'] ?? '';
    
    return CarPark(
      id: json['SegmentID'] ?? json['ParkingSegmentID'] ?? '',
      name: name,
      lat: lat,
      lon: lon,
      address: address,
      fareDescription: fareDesc,
      description: desc,
      type: 'on-street',
    );
  }
  
  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }
  
  CarPark _parseOffStreetCarPark(Map<String, dynamic> json) {
    String name = json['CarParkName']?['Zh_tw'] ?? '未知停車場';
    
    double lat = 0.0;
    double lon = 0.0;
    if (json['CarParkPosition'] != null) {
      lat = _safeParseDouble(json['CarParkPosition']['PositionLat']);
      lon = _safeParseDouble(json['CarParkPosition']['PositionLon']);
    }
    
    String address = json['Address'] ?? '';
    String fareDesc = json['FareDescription'] ?? '暫無費率資訊';
    String desc = json['Description'] ?? '';
    
    return CarPark(
      id: json['CarParkID'] ?? '',
      name: name,
      lat: lat,
      lon: lon,
      address: address,
      fareDescription: fareDesc,
      description: desc,
      type: 'off-street',
    );
  }

  List<CarPark> _sortByDistance(List<CarPark> parks, double userLat, double userLon) {
    for (var park in parks) {
      park.distance = _calculateDistance(userLat, userLon, park.lat, park.lon);
    }
    parks.sort((a, b) {
      final distA = a.distance ?? double.infinity;
      final distB = b.distance ?? double.infinity;
      return distA.compareTo(distB);
    });
    for (int i = 0; i < parks.length && i < 5; i++) {
      final park = parks[i];
      print('[TDX] 第${i+1}筆: ${park.name} (${park.distance!.toStringAsFixed(2)} km)');
    }
    return parks;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371;
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);
    final double deltaLatRad = _toRadians(lat2 - lat1);
    final double deltaLonRad = _toRadians(lon2 - lon1);
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
