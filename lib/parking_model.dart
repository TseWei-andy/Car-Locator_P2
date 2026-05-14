class TdxParkingResponse {
  final List<CarPark> carParks;

  TdxParkingResponse({required this.carParks});

  factory TdxParkingResponse.fromJson(Map<String, dynamic> json) {
    var list = json['CarParks'] as List? ?? [];
    List<CarPark> carParkList = list.map((i) => CarPark.fromJson(i)).toList();
    return TdxParkingResponse(carParks: carParkList);
  }
}

class CarPark {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String address;
  final String fareDescription;
  final String description;
  int? availableSpaces; // 預留給動態資料使用的欄位
  double? distance; // 與使用者的距離（公里）
  final String type; // 停車場類型：'on-street' 或 'off-street'

  CarPark({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.address,
    required this.fareDescription,
    required this.description,
    this.availableSpaces,
    this.distance,
    required this.type,
  });

  factory CarPark.fromJson(Map<String, dynamic> json, {String type = 'off-street'}) {
    String name;
    if (type == 'on-street') {
      name = json['Description'] ?? json['CarParkName']?['Zh_tw'] ?? '路邊停車';
    } else {
      name = json['CarParkName']?['Zh_tw'] ?? '未知停車場';
    }
    
    return CarPark(
      id: json['CarParkID'] ?? '',
      name: name,
      lat: (json['CarParkPosition']['PositionLat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['CarParkPosition']['PositionLon'] as num?)?.toDouble() ?? 0.0,
      address: json['Address'] ?? '',
      fareDescription: json['FareDescription'] ?? '暫無費率資訊',
      description: json['Description'] ?? '',
      type: type,
    );
  }
}