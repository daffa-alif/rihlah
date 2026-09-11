import 'package:flutter/material.dart';

class CustomAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final double fontSize;

  const CustomAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 64.0,
    this.fontSize = 24.0,
  });

  // Logika mengambil 1 atau 2 huruf awal dari nama
  String get _initials {
    if (name.isEmpty) return 'U'; // U untuk User jika nama kosong
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Jika ada URL foto, tampilkan fotonya
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Jika URL error/rusak, kembali ke inisial
          errorBuilder: (context, error, stackTrace) => _buildInitials(),
        ),
      );
    }
    // Jika tidak ada URL, tampilkan inisial
    return _buildInitials();
  }

  Widget _buildInitials() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1B6B4D), // Hijau khas RIHLAH
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}