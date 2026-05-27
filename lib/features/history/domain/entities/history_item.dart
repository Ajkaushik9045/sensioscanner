import 'dart:convert';
import 'package:equatable/equatable.dart';

class HistoryItem extends Equatable {
  const HistoryItem({
    required this.id,
    required this.name,
    required this.timestamp,
  });

  final String id;
  final String name;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryItem.fromJson(String source) =>
      HistoryItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  List<Object> get props => [id, name, timestamp];
}
