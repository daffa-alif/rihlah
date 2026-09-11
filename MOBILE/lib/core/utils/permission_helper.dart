import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

Future<bool> handleLocationPermission(BuildContext context) async {
  bool serviceEnabled;
  LocationPermission permission;

  // Cek apakah GPS di HP sedang menyala
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap aktifkan GPS (Lokasi) di HP kamu untuk melanjutkan.')),
      );
    }
    return false;
  }

  // Cek status perizinan saat ini
  permission = await Geolocator.checkPermission();

  // Jika belum diizinkan, munculkan pop-up sistem
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak. Fitur ini membutuhkan akses lokasi.')),
        );
      }
      return false;
    }
  }

  // Jika ditolak secara permanen oleh user
  if (permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin lokasi ditolak permanen. Silakan ubah melalui pengaturan HP.')),
      );
    }
    return false;
  }

  // Jika semua pengecekan lolos
  return true;
}