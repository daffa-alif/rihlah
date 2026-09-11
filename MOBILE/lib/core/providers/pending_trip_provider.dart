import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/trip_model.dart';

// Stores the current incoming trip while the driver is on the IncomingOrderScreen.
// Set by DriverHomeScreen when a Firestore trip arrives; cleared when the screen closes.
final pendingTripProvider = StateProvider<TripModel?>((ref) => null);
