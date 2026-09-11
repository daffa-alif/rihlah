// lib/data/mock/seed_data.dart
// Mock seed data for Prototype 2

import 'dart:math';
import 'package:flutter/material.dart';

// ── Passenger personas ────────────────────────────────────────────────────────

class PassengerPersona {
  const PassengerPersona({
    required this.id,
    required this.name,
    required this.phone,
    required this.initial,
    required this.color,
  });

  final String id;
  final String name;
  final String phone;
  final String initial;
  final Color  color;
}

const passengerPersonas = [
  PassengerPersona(
    id      : 'aisha',
    name    : 'Aisha Putri',
    phone   : '+62 812-3456-7890',
    initial : 'A',
    color   : Color(0xFFFF8C69), // accent500
  ),
  PassengerPersona(
    id      : 'budi',
    name    : 'Budi Santoso',
    phone   : '+62 811-2222-3333',
    initial : 'B',
    color   : Color(0xFF3B82F6), // info500
  ),
  PassengerPersona(
    id      : 'citra',
    name    : 'Citra Dewi',
    phone   : '+62 813-4444-5555',
    initial : 'C',
    color   : Color(0xFF22C55E), // success500
  ),
];

PassengerPersona getPersona(String id) =>
    passengerPersonas.firstWhere(
      (p) => p.id == id,
      orElse: () => passengerPersonas.first,
    );

// ── Driver personas ───────────────────────────────────────────────────────────

enum DriverServiceType { car, bike }

class DriverPersona {
  const DriverPersona({
    required this.id,
    required this.name,
    required this.initial,
    required this.color,
    required this.rating,
    required this.totalTrips,
    required this.vehicle,
    required this.vehicleYear,
    required this.vehicleColor,
    required this.plate,
    required this.serviceType,
    required this.memberSince,
  });

  final String            id;
  final String            name;
  final String            initial;
  final Color             color;
  final double            rating;
  final int               totalTrips;
  final String            vehicle;
  final int               vehicleYear;
  final String            vehicleColor;
  final String            plate;
  final DriverServiceType serviceType;
  final String            memberSince;

  bool get isCar  => serviceType == DriverServiceType.car;
  bool get isBike => serviceType == DriverServiceType.bike;

  /// Singkatan nama untuk avatar
  String get shortName => name.split(' ').take(2).join(' ');
}

const driverPersonas = [
  // ── Cars (5) ────────────────────────────────────
  DriverPersona(
    id           : 'iwan',
    name         : 'Pak Iwan Santoso',
    initial      : 'I',
    color        : Color(0xFF3B82F6),
    rating       : 4.9,
    totalTrips   : 1284,
    vehicle      : 'Toyota Avanza',
    vehicleYear  : 2019,
    vehicleColor : 'Silver',
    plate        : 'D 1234 ABC',
    serviceType  : DriverServiceType.car,
    memberSince  : "'22",
  ),
  DriverPersona(
    id           : 'bachtiar',
    name         : 'Pak Bachtiar',
    initial      : 'B',
    color        : Color(0xFF8B5CF6),
    rating       : 4.8,
    totalTrips   : 876,
    vehicle      : 'Honda Mobilio',
    vehicleYear  : 2020,
    vehicleColor : 'Putih',
    plate        : 'D 5678 DEF',
    serviceType  : DriverServiceType.car,
    memberSince  : "'21",
  ),
  DriverPersona(
    id           : 'dedi',
    name         : 'Kang Dedi',
    initial      : 'D',
    color        : Color(0xFFEF4444),
    rating       : 4.7,
    totalTrips   : 542,
    vehicle      : 'Daihatsu Xenia',
    vehicleYear  : 2018,
    vehicleColor : 'Hitam',
    plate        : 'D 9101 GHI',
    serviceType  : DriverServiceType.car,
    memberSince  : "'23",
  ),
  DriverPersona(
    id           : 'ujang',
    name         : 'Kang Ujang',
    initial      : 'U',
    color        : Color(0xFF22C55E),
    rating       : 5.0,
    totalTrips   : 2341,
    vehicle      : 'Toyota Calya',
    vehicleYear  : 2021,
    vehicleColor : 'Merah',
    plate        : 'D 1122 JKL',
    serviceType  : DriverServiceType.car,
    memberSince  : "'20",
  ),
  DriverPersona(
    id           : 'hendra',
    name         : 'Pak Hendra',
    initial      : 'H',
    color        : Color(0xFFF59E0B),
    rating       : 4.6,
    totalTrips   : 398,
    vehicle      : 'Suzuki Ertiga',
    vehicleYear  : 2022,
    vehicleColor : 'Abu-abu',
    plate        : 'D 3344 MNO',
    serviceType  : DriverServiceType.car,
    memberSince  : "'23",
  ),

  // ── Bikes (2) ───────────────────────────────────
  DriverPersona(
    id           : 'rizky',
    name         : 'Kang Rizky',
    initial      : 'R',
    color        : Color(0xFF06B6D4),
    rating       : 4.8,
    totalTrips   : 3102,
    vehicle      : 'Honda Beat',
    vehicleYear  : 2021,
    vehicleColor : 'Hitam',
    plate        : 'D 5566 PQR',
    serviceType  : DriverServiceType.bike,
    memberSince  : "'21",
  ),
  DriverPersona(
    id           : 'fajar',
    name         : 'Kang Fajar',
    initial      : 'F',
    color        : Color(0xFFFF8C69),
    rating       : 4.9,
    totalTrips   : 1876,
    vehicle      : 'Yamaha Mio',
    vehicleYear  : 2020,
    vehicleColor : 'Biru',
    plate        : 'D 7788 STU',
    serviceType  : DriverServiceType.bike,
    memberSince  : "'22",
  ),
];

/// Ambil driver berdasarkan service type secara acak (mock dispatch)
DriverPersona randomDriver(DriverServiceType type) {
  final filtered = driverPersonas
      .where((d) => d.serviceType == type)
      .toList();
  filtered.shuffle();
  return filtered.first;
}

/// Default driver untuk demo
final defaultDriver = driverPersonas[0]; // Pak Iwan

// ── Mock orders (untuk incoming_order_screen) ─────────────────────────────────

class MockOrder {
  const MockOrder({
    required this.id,
    required this.pickup,
    required this.pickupSub,
    required this.dropoff,
    required this.dropoffSub,
    required this.pickupLat,
    required this.pickupLon,
    required this.dropoffLat,
    required this.dropoffLon,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.service,
    required this.passengerName,
    required this.passengerRating,
    required this.driverDistanceKm,
  });

  final String id;
  final String pickup;
  final String pickupSub;
  final String dropoff;
  final String dropoffSub;
  final double pickupLat;
  final double pickupLon;
  final double dropoffLat;
  final double dropoffLon;
  final double distanceKm;
  final int    durationMin;
  final int    fare;
  final String service;
  final String passengerName;
  final double passengerRating;
  final double driverDistanceKm;
}

const mockOrders = [
  MockOrder(
    id              : 'order-001',
    pickup          : 'Dago Plaza',
    pickupSub       : 'Jl. Ir. H. Juanda No.1, Bandung',
    dropoff         : 'Trans Studio Bandung',
    dropoffSub      : 'Jl. Gatot Subroto No.289',
    pickupLat       : -6.8753,
    pickupLon       :  107.6171,
    dropoffLat      : -6.9081,
    dropoffLon      :  107.5963,
    distanceKm      : 3.2,
    durationMin     : 12,
    fare            : 18600,
    service         : 'car',
    passengerName   : 'Aisha P.',
    passengerRating : 4.9,
    driverDistanceKm: 0.9,
  ),
  MockOrder(
    id              : 'order-002',
    pickup          : 'ITB Ganesha',
    pickupSub       : 'Jl. Ganesha No.10, Bandung',
    dropoff         : 'Cihampelas Walk',
    dropoffSub      : 'Jl. Cihampelas No.160',
    pickupLat       : -6.8942,
    pickupLon       :  107.6103,
    dropoffLat      : -6.8870,
    dropoffLon      :  107.5972,
    distanceKm      : 2.1,
    durationMin     : 9,
    fare            : 13400,
    service         : 'bike',
    passengerName   : 'Budi S.',
    passengerRating : 4.7,
    driverDistanceKm: 0.4,
  ),
  MockOrder(
    id              : 'order-003',
    pickup          : 'Bandung Station',
    pickupSub       : 'Jl. Stasiun Timur No.1',
    dropoff         : 'Braga Culinary Night',
    dropoffSub      : 'Jl. Braga, Bandung',
    pickupLat       : -6.9142,
    pickupLon       :  107.6038,
    dropoffLat      : -6.9108,
    dropoffLon      :  107.6077,
    distanceKm      : 1.8,
    durationMin     : 8,
    fare            : 11200,
    service         : 'car',
    passengerName   : 'Citra M.',
    passengerRating : 5.0,
    driverDistanceKm: 1.2,
  ),
  MockOrder(
    id              : 'order-004',
    pickup          : 'Paris Van Java Mall',
    pickupSub       : 'Jl. Sukajadi No.131-139',
    dropoff         : 'Floating Market Lembang',
    dropoffSub      : 'Jl. Grand Hotel No.33E, Lembang',
    pickupLat       : -6.8818,
    pickupLon       :  107.5901,
    dropoffLat      : -6.8169,
    dropoffLon      :  107.6169,
    distanceKm      : 9.4,
    durationMin     : 28,
    fare            : 41900,
    service         : 'car',
    passengerName   : 'Reza A.',
    passengerRating : 4.8,
    driverDistanceKm: 0.6,
  ),
  MockOrder(
    id              : 'order-005',
    pickup          : 'Alun-Alun Bandung',
    pickupSub       : 'Jl. Asia Afrika, Bandung',
    dropoff         : 'Jl. Buah Batu',
    dropoffSub      : 'Jl. Buah Batu No.50',
    pickupLat       : -6.9210,
    pickupLon       :  107.6054,
    dropoffLat      : -6.9397,
    dropoffLon      :  107.6328,
    distanceKm      : 4.7,
    durationMin     : 16,
    fare            : 9400,
    service         : 'bike',
    passengerName   : 'Siti N.',
    passengerRating : 4.6,
    driverDistanceKm: 0.3,
  ),
];

/// Ambil order berdasarkan ID. Jika tidak ditemukan, kembalikan order pertama.
MockOrder getOrder(String id) {
  try {
    return mockOrders.firstWhere((o) => o.id == id);
  } catch (_) {
    return mockOrders[Random().nextInt(mockOrders.length)];
  }
}

/// Ambil driver berdasarkan ID.
DriverPersona getDriverById(String id) {
  try {
    return driverPersonas.firstWhere((d) => d.id == id);
  } catch (_) {
    return driverPersonas.first;
  }
}

// ── Rating model ──────────────────────────────────────────────────────────────

/// Tag pujian yang bisa diberikan passenger.
/// Digunakan di rating event dan untuk tag cloud di profile.
const ratingTags = [
  'Ramah',
  'Tepat waktu',
  'Nyaman',
  'Aman',
  'Mobil bersih',
  'Rute pintar',
  'Profesional',
  'Komunikatif',
];

/// Seed rating events ke Hive untuk demo.
/// Key: rating_events_{driverId}
/// Format: [{tripId, rating, tags, date}] — tanpa nama passenger (privacy).
void seedRatingEvents(String driverId) {
  final box = HiveRatingSeeder._box;
  if (box == null) return;

  final key     = 'rating_events_$driverId';
  final existing = box.get(key) as List?;

  // Jangan seed ulang jika sudah ada data
  if (existing != null && existing.isNotEmpty) return;

  final rng  = Random(42); // seed tetap agar data konsisten
  final now  = DateTime.now();
  final events = <Map<String, dynamic>>[];

  // Generate 45 rating events dalam 35 hari terakhir
  // Distribusi realistis: mayoritas 4–5, sedikit 3, jarang 1–2
  const distribution = [5, 5, 5, 5, 4, 4, 4, 4, 4, 3, 4, 5, 5, 4, 5];

  for (int i = 0; i < 45; i++) {
    final daysAgo = rng.nextInt(35);
    final date    = now.subtract(Duration(
      days    : daysAgo,
      hours   : rng.nextInt(14) + 7,  // 07:00–21:00
      minutes : rng.nextInt(60),
    ));

    // Rating berdasarkan distribusi, tambahkan sedikit variasi
    final baseRating = distribution[i % distribution.length];
    final rating     = (baseRating + (rng.nextDouble() * 0.8 - 0.2))
        .clamp(1.0, 5.0);
    final roundedRating = (rating * 2).round() / 2; // 0.5 step

    // Tags: lebih banyak tag untuk rating tinggi
    final tagCount  = roundedRating >= 4.5 ? rng.nextInt(3) + 2
                    : roundedRating >= 3.5 ? rng.nextInt(2) + 1
                    : 0;
    final shuffled  = [...ratingTags]..shuffle(rng);
    final tags      = shuffled.take(tagCount).toList();

    events.add({
      'tripId': 'trip-seed-${i.toString().padLeft(3, '0')}',
      'rating': roundedRating,
      'tags'  : tags,
      'date'  : date.toIso8601String(),
    });
  }

  // Urutkan dari terbaru
  events.sort((a, b) => b['date'].compareTo(a['date']));
  box.put(key, events);
}

/// Helper untuk akses Hive box dari seed function.
/// Harus di-init sebelum seedRatingEvents dipanggil.
class HiveRatingSeeder {
  HiveRatingSeeder._();
  static dynamic _box;
  static void init(dynamic box) => _box = box;
}

// ── RatingStats ───────────────────────────────────────────────────────────────

/// Satu event rating dari passenger.
/// PRIVASI: nama passenger TIDAK disimpan di sini — hanya tripId
/// sebagai referensi internal yang tidak ditampilkan ke driver.
class RatingEvent {
  const RatingEvent({
    required this.tripId,
    required this.rating,
    required this.tags,
    required this.date,
  });
  final String       tripId;
  final double       rating;
  final List<String> tags;
  final DateTime     date;
}

class RatingStats {
  const RatingStats({
    required this.events,
    required this.average,
    required this.starCounts,
    required this.tagCounts,
    required this.trend30,
    required this.isLow,
  });

  final List<RatingEvent>    events;
  final double               average;
  final Map<int, int>        starCounts;   // {5:20, 4:15, 3:3, 2:1, 1:0}
  final Map<String, int>     tagCounts;    // {'Ramah': 18, ...}
  /// Rata-rata rating per hari dalam 30 hari terakhir.
  /// List 30 elemen, index 0 = 29 hari lalu, index 29 = hari ini.
  final List<double?>        trend30;
  final bool                 isLow;        // average < 4.5

  static RatingStats load(String driverId) {
    final box    = HiveRatingSeeder._box;
    final key    = 'rating_events_$driverId';
    final raw    = (box?.get(key) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final events = raw.map((m) {
      final tags = (m['tags'] as List? ?? [])
          .map((t) => t.toString())
          .toList();
      return RatingEvent(
        tripId: m['tripId']?.toString() ?? '',
        rating: (m['rating'] as num?)?.toDouble() ?? 5.0,
        tags  : tags,
        date  : DateTime.tryParse(m['date']?.toString() ?? '')
            ?.toLocal() ?? DateTime.now(),
      );
    }).toList();

    if (events.isEmpty) {
      return RatingStats(
        events    : [],
        average   : 0,
        starCounts: {5:0, 4:0, 3:0, 2:0, 1:0},
        tagCounts : {},
        trend30   : List.filled(30, null),
        isLow     : false,
      );
    }

    // Average
    final avg = events.fold(0.0, (s, e) => s + e.rating) / events.length;

    // Star counts (bulatkan ke bintang terdekat)
    final stars = {5:0, 4:0, 3:0, 2:0, 1:0};
    for (final e in events) {
      final s = e.rating.round().clamp(1, 5);
      stars[s] = (stars[s] ?? 0) + 1;
    }

    // Tag counts
    final tags = <String, int>{};
    for (final e in events) {
      for (final t in e.tags) {
        tags[t] = (tags[t] ?? 0) + 1;
      }
    }

    // 30-day trend
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trend = List<double?>.filled(30, null);
    for (int i = 0; i < 30; i++) {
      final day    = today.subtract(Duration(days: 29 - i));
      final dayEnd = day.add(const Duration(days: 1));
      final dayEvs = events.where((e) =>
          !e.date.isBefore(day) && e.date.isBefore(dayEnd)).toList();
      if (dayEvs.isNotEmpty) {
        trend[i] = dayEvs.fold(0.0, (s, e) => s + e.rating) / dayEvs.length;
      }
    }

    return RatingStats(
      events    : events,
      average   : double.parse(avg.toStringAsFixed(2)),
      starCounts: stars,
      tagCounts : tags,
      trend30   : trend,
      isLow     : avg < 4.5,
    );
  }
}