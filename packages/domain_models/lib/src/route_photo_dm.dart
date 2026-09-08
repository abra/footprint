import 'package:equatable/equatable.dart';

enum PhotoSource { camera, gallery }

class RoutePhotoDM extends Equatable {
  const RoutePhotoDM({
    required this.id,
    required this.routeId,
    required this.path,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.comment = '',
  });

  static const maxCommentLength = 1000;

  final String id;
  final int routeId;
  final String path;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final String comment;

  RoutePhotoDM copyWith({String? comment}) => RoutePhotoDM(
    id: id,
    routeId: routeId,
    path: path,
    latitude: latitude,
    longitude: longitude,
    capturedAt: capturedAt,
    comment: comment ?? this.comment,
  );

  @override
  List<Object?> get props => [
    id,
    routeId,
    path,
    latitude,
    longitude,
    capturedAt,
    comment,
  ];
}
