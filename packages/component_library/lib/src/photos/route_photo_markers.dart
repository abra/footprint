import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'route_photo_image.dart';
import 'route_photo_viewer.dart';

class RoutePhotoMarkers extends StatelessWidget {
  const RoutePhotoMarkers({super.key, required this.photos});
  final List<RoutePhotoDM> photos;

  @override
  Widget build(BuildContext context) => MarkerLayer(
    markers: [
      for (final photo in photos)
        Marker(
          point: LatLng(photo.latitude, photo.longitude),
          width: 56,
          height: 66,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: 'Open route photo',
            child: Semantics(
              button: true,
              label: 'Open route photo',
              child: GestureDetector(
                onTap: () => unawaited(
                  showRoutePhotoViewer(
                    context,
                    photos: photos,
                    selected: photo,
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      bottom: 0,
                      left: 16,
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 56,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: ClipOval(child: RoutePhotoImage(photo: photo)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
