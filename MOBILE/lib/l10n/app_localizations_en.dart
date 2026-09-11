// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'RIHLAH';

  @override
  String get greeting_morning => 'Good morning,';

  @override
  String get greeting_afternoon => 'Good afternoon,';

  @override
  String get greeting_evening => 'Good evening,';

  @override
  String get onboarding_title_1 => 'Bandung\'s ride,\nyour way.';

  @override
  String get onboarding_sub_1 =>
      'Order a ride in seconds. On time, every time.';

  @override
  String get onboarding_title_2 => 'Fair fares.\nReal drivers.';

  @override
  String get onboarding_sub_2 =>
      'See exactly what your driver earns. Transparent, no hidden fees.';

  @override
  String get onboarding_title_3 => 'Safe\nby design.';

  @override
  String get onboarding_sub_3 =>
      'One-tap SOS, live trip sharing, and community-verified drivers.';

  @override
  String get onboarding_skip => 'Skip';

  @override
  String get onboarding_next => 'Next';

  @override
  String get onboarding_start => 'Get Started';

  @override
  String get auth_sign_in => 'Sign in';

  @override
  String get auth_sign_in_subtitle =>
      'We\'ll send a 4-digit code to verify your phone.';

  @override
  String get auth_continue => 'Continue';

  @override
  String get auth_otp_title => 'Enter the 4-digit code';

  @override
  String get auth_otp_sent_to => 'Sent to';

  @override
  String get auth_otp_edit => 'Edit';

  @override
  String get auth_otp_resend_in => 'Resend in';

  @override
  String get auth_otp_resend => 'Resend code';

  @override
  String get auth_otp_verify => 'Verify';

  @override
  String get auth_terms => 'By continuing, you agree to RIHLAH\'s';

  @override
  String get auth_terms_link => 'Terms';

  @override
  String get auth_privacy_link => 'Privacy Policy';

  @override
  String get role_title => 'How will you use RIHLAH today?';

  @override
  String get role_subtitle => 'You can switch any time from Profile.';

  @override
  String get role_passenger => 'Order a ride';

  @override
  String get role_passenger_sub => 'Cars, bikes, or send a package';

  @override
  String get role_driver => 'Drive with us';

  @override
  String get role_driver_sub => 'Earn on your own schedule';

  @override
  String get home_where_to => 'Where to?';

  @override
  String get home_saved_places => 'SAVED PLACES';

  @override
  String get home_promotions => 'PROMOTIONS';

  @override
  String get search_title => 'Set your destination';

  @override
  String get search_current => 'Current location';

  @override
  String get search_placeholder => 'Where to?';

  @override
  String get search_suggested => 'SUGGESTED PLACES';

  @override
  String get search_saved => 'SAVED PLACES';

  @override
  String get search_no_results => 'No results for';

  @override
  String get search_results => 'RESULTS';

  @override
  String get services_title => 'Choose your ride';

  @override
  String get services_pick => 'Pick a service';

  @override
  String get services_car => 'RIHLAH Car';

  @override
  String get services_car_sub => 'Comfortable, AC, up to 4 seats';

  @override
  String get services_bike => 'RIHLAH Bike';

  @override
  String get services_bike_sub => 'Fast through traffic, 1 seat';

  @override
  String get services_send => 'RIHLAH Send';

  @override
  String get services_send_sub => 'Parcels and documents';

  @override
  String get confirm_title => 'Confirm your ride';

  @override
  String get confirm_payment => 'Cash';

  @override
  String get confirm_add_voucher => 'Add voucher';

  @override
  String get confirm_note_placeholder => 'Add a note for driver';

  @override
  String get confirm_fare_breakdown => 'Fare breakdown';

  @override
  String get confirm_base => 'Base';

  @override
  String get confirm_distance => 'Distance';

  @override
  String get confirm_time => 'Time';

  @override
  String get confirm_voucher => 'Voucher';

  @override
  String get confirm_total => 'Total';

  @override
  String get confirm_order_cta => 'Order RIHLAH Car';

  @override
  String get searching_looking => 'Looking for nearby drivers…';

  @override
  String get searching_almost => 'Almost there…';

  @override
  String get searching_hang => 'Hang tight…';

  @override
  String get searching_matching => 'Hang tight, we\'re matching you';

  @override
  String get searching_cancel => 'Cancel order';

  @override
  String get trip_driver_on_way => 'Driver is on the way';

  @override
  String get trip_driver_arriving => 'Driver is arriving';

  @override
  String get trip_driver_here => 'Your driver is here!';

  @override
  String get trip_in_trip => 'In trip';

  @override
  String get trip_on_way => 'On the way to destination';

  @override
  String get trip_share => 'Share trip';

  @override
  String get trip_call => 'Call';

  @override
  String get trip_chat => 'Chat';

  @override
  String get trip_cancel => 'Cancel';

  @override
  String get trip_cancelled => 'Cancelled';

  @override
  String get complete_arrived => 'You\'ve arrived';

  @override
  String get complete_you_paid => 'You paid';

  @override
  String get complete_cash_to => 'Cash to';

  @override
  String get complete_rate_driver => 'How was your ride?';

  @override
  String get complete_add_tip => 'Add a tip?';

  @override
  String get complete_submit => 'Submit';

  @override
  String get complete_skip => 'Skip';

  @override
  String get activity_title => 'Activity';

  @override
  String get activity_trips => 'Trips';

  @override
  String get activity_receipts => 'Receipts';

  @override
  String get activity_today => 'TODAY';

  @override
  String get activity_yesterday => 'YESTERDAY';

  @override
  String get activity_this_week => 'THIS WEEK';

  @override
  String get activity_earlier => 'EARLIER';

  @override
  String get activity_empty_title => 'No trips yet';

  @override
  String get activity_empty_body => 'Your trips will appear here';

  @override
  String get activity_order_ride => 'Order a ride';

  @override
  String get activity_reorder => 'Reorder this trip?';

  @override
  String get profile_title => 'Profile';

  @override
  String get profile_dark_mode => 'Dark mode';

  @override
  String get profile_trips => 'Trips';

  @override
  String get profile_rating => 'Rating';

  @override
  String get profile_member => 'Member';

  @override
  String get profile_payment => 'Payment methods';

  @override
  String get profile_safety => 'Safety & SOS';

  @override
  String get profile_language => 'Language';

  @override
  String get profile_help => 'Help';

  @override
  String get profile_switch_driver => 'Switch to driver mode';

  @override
  String get profile_switch_driver_sub => 'Earn with RIHLAH';

  @override
  String get profile_switch_passenger => 'Switch to passenger mode';

  @override
  String get profile_switch_passenger_sub => 'Order a ride';

  @override
  String get profile_sign_out => 'Sign out';

  @override
  String get doc_section_label => 'DOCUMENTS';

  @override
  String get settings_section_label => 'SETTINGS';

  @override
  String get driver_since => 'Driver since';

  @override
  String get driver_home_welcome => 'Welcome back,';

  @override
  String get driver_home_earnings => 'Today\'s earnings';

  @override
  String get driver_home_online => 'Online';

  @override
  String get driver_home_offline => 'Offline';

  @override
  String get driver_home_go_online => 'Go online';

  @override
  String get driver_home_go_offline => 'Go offline';

  @override
  String get driver_home_visible => 'You are visible';

  @override
  String get incoming_title => 'New order nearby';

  @override
  String get incoming_from_you => 'from you';

  @override
  String get incoming_will_earn => 'You\'ll earn';

  @override
  String get incoming_total_trip => 'Total trip';

  @override
  String get incoming_accept => 'Accept';

  @override
  String get incoming_pass => 'Pass';

  @override
  String get incoming_expired => 'Order expired';

  @override
  String get driver_trip_picking_up => 'Picking up';

  @override
  String get driver_trip_waiting => 'Waiting for passenger';

  @override
  String get driver_trip_dropping => 'Dropping off';

  @override
  String get driver_trip_arrived => 'I\'ve arrived';

  @override
  String get driver_trip_start => 'Start trip';

  @override
  String get driver_trip_pickup_label => 'PICKUP';

  @override
  String get driver_trip_passenger_way => 'Passenger is on their way';

  @override
  String get driver_trip_in_banner => 'In trip · heading to destination';

  @override
  String get collect_title => 'Collect payment';

  @override
  String get collect_total_fare => 'Total fare';

  @override
  String get collect_cash => 'Cash payment';

  @override
  String get collect_platform_fee => 'Platform fee (20%)';

  @override
  String get collect_your_earn => 'Your earnings';

  @override
  String get collect_mark_paid => 'Mark as paid';

  @override
  String get collect_saving => 'Saving…';

  @override
  String get collect_earned => 'Earned';

  @override
  String get collect_trip_ended => 'Trip ended at Trans Studio Bandung';

  @override
  String get earnings_title => 'Earnings';

  @override
  String get earnings_today => 'Today';

  @override
  String get earnings_week => 'Week';

  @override
  String get earnings_month => 'Month';

  @override
  String get earnings_withdraw => 'Withdraw to bank';

  @override
  String get earnings_breakdown => 'Breakdown';

  @override
  String get earnings_base => 'Base fare';

  @override
  String get earnings_surge => 'Surge';

  @override
  String get earnings_tips => 'Tips';

  @override
  String get earnings_recent => 'RECENT TRIPS';

  @override
  String get earnings_label_today => 'Total earned today';

  @override
  String get earnings_label_week => 'Total earned this week';

  @override
  String get earnings_label_month => 'Total earned this month';

  @override
  String get history_title => 'History';

  @override
  String get history_all => 'All';

  @override
  String get history_today => 'Today';

  @override
  String get history_this_week => 'This week';

  @override
  String get history_empty_title => 'No trips yet';

  @override
  String get history_empty_body => 'Complete trips to see your history';

  @override
  String get history_go_online => 'Start driving';

  @override
  String get sos_triggered => 'SOS triggered';

  @override
  String get sos_help_way => 'Help is on the way';

  @override
  String get sos_sharing => 'Sharing your live location with trusted contacts';

  @override
  String get sos_call_police => 'Call police 110';

  @override
  String get sos_call_sub => 'Direct line to local emergency';

  @override
  String get sos_share_contacts => 'Share with trusted contacts';

  @override
  String get sos_share_sub => 'Live location for next 30 min';

  @override
  String get sos_cancel => 'Cancel SOS';

  @override
  String get sos_share_title => 'Share location';

  @override
  String get sos_share_body =>
      'Live location for 30 minutes to trusted contacts:';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_close => 'Close';

  @override
  String get common_save => 'Save';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_coming_soon => 'Coming soon';

  @override
  String get searchingLooking => 'Looking for nearby drivers…';

  @override
  String get searchingAlmost => 'Almost there…';

  @override
  String get searchingHang => 'Hang tight…';

  @override
  String get searchingMatching => 'Hang tight, we\'re matching you';

  @override
  String get searchingCancel => 'Cancel order';

  @override
  String get cancelOrderTitle => 'Cancel order?';

  @override
  String get cancelOrderBody =>
      'You won\'t be charged. The driver will be notified.';

  @override
  String get cancelYes => 'Yes, cancel';

  @override
  String get cancelKeep => 'Keep order';
}
