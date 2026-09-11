import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appName.
  ///
  /// In id, this message translates to:
  /// **'RIHLAH'**
  String get appName;

  /// No description provided for @greeting_morning.
  ///
  /// In id, this message translates to:
  /// **'Selamat pagi,'**
  String get greeting_morning;

  /// No description provided for @greeting_afternoon.
  ///
  /// In id, this message translates to:
  /// **'Selamat siang,'**
  String get greeting_afternoon;

  /// No description provided for @greeting_evening.
  ///
  /// In id, this message translates to:
  /// **'Selamat malam,'**
  String get greeting_evening;

  /// No description provided for @onboarding_title_1.
  ///
  /// In id, this message translates to:
  /// **'Transportasi \nsesuai keinginanmu.'**
  String get onboarding_title_1;

  /// No description provided for @onboarding_sub_1.
  ///
  /// In id, this message translates to:
  /// **'Pesan ojek atau mobil dalam hitungan detik. Tepat waktu, setiap saat.'**
  String get onboarding_sub_1;

  /// No description provided for @onboarding_title_2.
  ///
  /// In id, this message translates to:
  /// **'Tarif jujur.\nDriver nyata.'**
  String get onboarding_title_2;

  /// No description provided for @onboarding_sub_2.
  ///
  /// In id, this message translates to:
  /// **'Lihat persis berapa yang diterima driver. Transparan, tanpa biaya tersembunyi.'**
  String get onboarding_sub_2;

  /// No description provided for @onboarding_title_3.
  ///
  /// In id, this message translates to:
  /// **'Aman\nsejak awal.'**
  String get onboarding_title_3;

  /// No description provided for @onboarding_sub_3.
  ///
  /// In id, this message translates to:
  /// **'SOS satu tap, berbagi perjalanan live, dan driver terverifikasi komunitas.'**
  String get onboarding_sub_3;

  /// No description provided for @onboarding_skip.
  ///
  /// In id, this message translates to:
  /// **'Lewati'**
  String get onboarding_skip;

  /// No description provided for @onboarding_next.
  ///
  /// In id, this message translates to:
  /// **'Lanjut'**
  String get onboarding_next;

  /// No description provided for @onboarding_start.
  ///
  /// In id, this message translates to:
  /// **'Mulai Sekarang'**
  String get onboarding_start;

  /// No description provided for @auth_sign_in.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get auth_sign_in;

  /// No description provided for @auth_sign_in_subtitle.
  ///
  /// In id, this message translates to:
  /// **'Kami akan mengirimkan kode 4 digit untuk verifikasi nomor kamu.'**
  String get auth_sign_in_subtitle;

  /// No description provided for @auth_continue.
  ///
  /// In id, this message translates to:
  /// **'Lanjut'**
  String get auth_continue;

  /// No description provided for @auth_otp_title.
  ///
  /// In id, this message translates to:
  /// **'Masukkan kode 4 digit'**
  String get auth_otp_title;

  /// No description provided for @auth_otp_sent_to.
  ///
  /// In id, this message translates to:
  /// **'Dikirim ke'**
  String get auth_otp_sent_to;

  /// No description provided for @auth_otp_edit.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get auth_otp_edit;

  /// No description provided for @auth_otp_resend_in.
  ///
  /// In id, this message translates to:
  /// **'Kirim ulang dalam'**
  String get auth_otp_resend_in;

  /// No description provided for @auth_otp_resend.
  ///
  /// In id, this message translates to:
  /// **'Kirim ulang kode'**
  String get auth_otp_resend;

  /// No description provided for @auth_otp_verify.
  ///
  /// In id, this message translates to:
  /// **'Verifikasi'**
  String get auth_otp_verify;

  /// No description provided for @auth_terms.
  ///
  /// In id, this message translates to:
  /// **'Dengan melanjutkan, kamu setuju dengan'**
  String get auth_terms;

  /// No description provided for @auth_terms_link.
  ///
  /// In id, this message translates to:
  /// **'Syarat & Ketentuan'**
  String get auth_terms_link;

  /// No description provided for @auth_privacy_link.
  ///
  /// In id, this message translates to:
  /// **'Kebijakan Privasi'**
  String get auth_privacy_link;

  /// No description provided for @role_title.
  ///
  /// In id, this message translates to:
  /// **'Bagaimana kamu akan menggunakan RIHLAH hari ini?'**
  String get role_title;

  /// No description provided for @role_subtitle.
  ///
  /// In id, this message translates to:
  /// **'Kamu bisa berganti kapan saja dari Profil.'**
  String get role_subtitle;

  /// No description provided for @role_passenger.
  ///
  /// In id, this message translates to:
  /// **'Pesan perjalanan'**
  String get role_passenger;

  /// No description provided for @role_passenger_sub.
  ///
  /// In id, this message translates to:
  /// **'Mobil, motor, atau kirim paket'**
  String get role_passenger_sub;

  /// No description provided for @role_driver.
  ///
  /// In id, this message translates to:
  /// **'Berkendara bersama kami'**
  String get role_driver;

  /// No description provided for @role_driver_sub.
  ///
  /// In id, this message translates to:
  /// **'Hasilkan uang sesuai jadwalmu'**
  String get role_driver_sub;

  /// No description provided for @home_where_to.
  ///
  /// In id, this message translates to:
  /// **'Mau ke mana?'**
  String get home_where_to;

  /// No description provided for @home_saved_places.
  ///
  /// In id, this message translates to:
  /// **'TEMPAT TERSIMPAN'**
  String get home_saved_places;

  /// No description provided for @home_promotions.
  ///
  /// In id, this message translates to:
  /// **'PROMOSI'**
  String get home_promotions;

  /// No description provided for @search_title.
  ///
  /// In id, this message translates to:
  /// **'Atur tujuanmu'**
  String get search_title;

  /// No description provided for @search_current.
  ///
  /// In id, this message translates to:
  /// **'Lokasi saat ini'**
  String get search_current;

  /// No description provided for @search_placeholder.
  ///
  /// In id, this message translates to:
  /// **'Mau ke mana?'**
  String get search_placeholder;

  /// No description provided for @search_suggested.
  ///
  /// In id, this message translates to:
  /// **'TEMPAT SARAN'**
  String get search_suggested;

  /// No description provided for @search_saved.
  ///
  /// In id, this message translates to:
  /// **'TEMPAT TERSIMPAN'**
  String get search_saved;

  /// No description provided for @search_no_results.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada hasil untuk'**
  String get search_no_results;

  /// No description provided for @search_results.
  ///
  /// In id, this message translates to:
  /// **'HASIL'**
  String get search_results;

  /// No description provided for @services_title.
  ///
  /// In id, this message translates to:
  /// **'Pilih perjalanan'**
  String get services_title;

  /// No description provided for @services_pick.
  ///
  /// In id, this message translates to:
  /// **'Pilih layanan'**
  String get services_pick;

  /// No description provided for @services_car.
  ///
  /// In id, this message translates to:
  /// **'RIHLAH Car'**
  String get services_car;

  /// No description provided for @services_car_sub.
  ///
  /// In id, this message translates to:
  /// **'Nyaman, AC, hingga 4 kursi'**
  String get services_car_sub;

  /// No description provided for @services_bike.
  ///
  /// In id, this message translates to:
  /// **'RIHLAH Bike'**
  String get services_bike;

  /// No description provided for @services_bike_sub.
  ///
  /// In id, this message translates to:
  /// **'Cepat menembus macet, 1 kursi'**
  String get services_bike_sub;

  /// No description provided for @services_send.
  ///
  /// In id, this message translates to:
  /// **'RIHLAH Send'**
  String get services_send;

  /// No description provided for @services_send_sub.
  ///
  /// In id, this message translates to:
  /// **'Paket dan dokumen'**
  String get services_send_sub;

  /// No description provided for @confirm_title.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi perjalanan'**
  String get confirm_title;

  /// No description provided for @confirm_payment.
  ///
  /// In id, this message translates to:
  /// **'Tunai'**
  String get confirm_payment;

  /// No description provided for @confirm_add_voucher.
  ///
  /// In id, this message translates to:
  /// **'Tambah voucher'**
  String get confirm_add_voucher;

  /// No description provided for @confirm_note_placeholder.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan catatan untuk driver'**
  String get confirm_note_placeholder;

  /// No description provided for @confirm_fare_breakdown.
  ///
  /// In id, this message translates to:
  /// **'Rincian tarif'**
  String get confirm_fare_breakdown;

  /// No description provided for @confirm_base.
  ///
  /// In id, this message translates to:
  /// **'Tarif dasar'**
  String get confirm_base;

  /// No description provided for @confirm_distance.
  ///
  /// In id, this message translates to:
  /// **'Jarak'**
  String get confirm_distance;

  /// No description provided for @confirm_time.
  ///
  /// In id, this message translates to:
  /// **'Waktu'**
  String get confirm_time;

  /// No description provided for @confirm_voucher.
  ///
  /// In id, this message translates to:
  /// **'Voucher'**
  String get confirm_voucher;

  /// No description provided for @confirm_total.
  ///
  /// In id, this message translates to:
  /// **'Total'**
  String get confirm_total;

  /// No description provided for @confirm_order_cta.
  ///
  /// In id, this message translates to:
  /// **'Pesan RIHLAH Car'**
  String get confirm_order_cta;

  /// No description provided for @searching_looking.
  ///
  /// In id, this message translates to:
  /// **'Mencari driver terdekat…'**
  String get searching_looking;

  /// No description provided for @searching_almost.
  ///
  /// In id, this message translates to:
  /// **'Hampir ada…'**
  String get searching_almost;

  /// No description provided for @searching_hang.
  ///
  /// In id, this message translates to:
  /// **'Tunggu sebentar…'**
  String get searching_hang;

  /// No description provided for @searching_matching.
  ///
  /// In id, this message translates to:
  /// **'Sedang mencarikan driver untukmu'**
  String get searching_matching;

  /// No description provided for @searching_cancel.
  ///
  /// In id, this message translates to:
  /// **'Batalkan pesanan'**
  String get searching_cancel;

  /// No description provided for @trip_driver_on_way.
  ///
  /// In id, this message translates to:
  /// **'Driver sedang menuju kamu'**
  String get trip_driver_on_way;

  /// No description provided for @trip_driver_arriving.
  ///
  /// In id, this message translates to:
  /// **'Driver hampir sampai'**
  String get trip_driver_arriving;

  /// No description provided for @trip_driver_here.
  ///
  /// In id, this message translates to:
  /// **'Driver sudah di sini!'**
  String get trip_driver_here;

  /// No description provided for @trip_in_trip.
  ///
  /// In id, this message translates to:
  /// **'Dalam perjalanan'**
  String get trip_in_trip;

  /// No description provided for @trip_on_way.
  ///
  /// In id, this message translates to:
  /// **'Dalam perjalanan ke tujuan'**
  String get trip_on_way;

  /// No description provided for @trip_share.
  ///
  /// In id, this message translates to:
  /// **'Bagikan perjalanan'**
  String get trip_share;

  /// No description provided for @trip_call.
  ///
  /// In id, this message translates to:
  /// **'Telepon'**
  String get trip_call;

  /// No description provided for @trip_chat.
  ///
  /// In id, this message translates to:
  /// **'Chat'**
  String get trip_chat;

  /// No description provided for @trip_cancel.
  ///
  /// In id, this message translates to:
  /// **'Batalkan'**
  String get trip_cancel;

  /// No description provided for @trip_cancelled.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan'**
  String get trip_cancelled;

  /// No description provided for @complete_arrived.
  ///
  /// In id, this message translates to:
  /// **'Kamu sudah sampai'**
  String get complete_arrived;

  /// No description provided for @complete_you_paid.
  ///
  /// In id, this message translates to:
  /// **'Kamu membayar'**
  String get complete_you_paid;

  /// No description provided for @complete_cash_to.
  ///
  /// In id, this message translates to:
  /// **'Tunai ke'**
  String get complete_cash_to;

  /// No description provided for @complete_rate_driver.
  ///
  /// In id, this message translates to:
  /// **'Bagaimana perjalananmu?'**
  String get complete_rate_driver;

  /// No description provided for @complete_add_tip.
  ///
  /// In id, this message translates to:
  /// **'Tambah tip?'**
  String get complete_add_tip;

  /// No description provided for @complete_submit.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get complete_submit;

  /// No description provided for @complete_skip.
  ///
  /// In id, this message translates to:
  /// **'Lewati'**
  String get complete_skip;

  /// No description provided for @activity_title.
  ///
  /// In id, this message translates to:
  /// **'Aktivitas'**
  String get activity_title;

  /// No description provided for @activity_trips.
  ///
  /// In id, this message translates to:
  /// **'Perjalanan'**
  String get activity_trips;

  /// No description provided for @activity_receipts.
  ///
  /// In id, this message translates to:
  /// **'Struk'**
  String get activity_receipts;

  /// No description provided for @activity_today.
  ///
  /// In id, this message translates to:
  /// **'HARI INI'**
  String get activity_today;

  /// No description provided for @activity_yesterday.
  ///
  /// In id, this message translates to:
  /// **'KEMARIN'**
  String get activity_yesterday;

  /// No description provided for @activity_this_week.
  ///
  /// In id, this message translates to:
  /// **'MINGGU INI'**
  String get activity_this_week;

  /// No description provided for @activity_earlier.
  ///
  /// In id, this message translates to:
  /// **'LEBIH AWAL'**
  String get activity_earlier;

  /// No description provided for @activity_empty_title.
  ///
  /// In id, this message translates to:
  /// **'Belum ada perjalanan'**
  String get activity_empty_title;

  /// No description provided for @activity_empty_body.
  ///
  /// In id, this message translates to:
  /// **'Perjalananmu akan muncul di sini'**
  String get activity_empty_body;

  /// No description provided for @activity_order_ride.
  ///
  /// In id, this message translates to:
  /// **'Pesan perjalanan'**
  String get activity_order_ride;

  /// No description provided for @activity_reorder.
  ///
  /// In id, this message translates to:
  /// **'Pesan ulang perjalanan ini?'**
  String get activity_reorder;

  /// No description provided for @profile_title.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get profile_title;

  /// No description provided for @profile_dark_mode.
  ///
  /// In id, this message translates to:
  /// **'Mode malam'**
  String get profile_dark_mode;

  /// No description provided for @profile_trips.
  ///
  /// In id, this message translates to:
  /// **'Perjalanan'**
  String get profile_trips;

  /// No description provided for @profile_rating.
  ///
  /// In id, this message translates to:
  /// **'Rating'**
  String get profile_rating;

  /// No description provided for @profile_member.
  ///
  /// In id, this message translates to:
  /// **'Member'**
  String get profile_member;

  /// No description provided for @profile_payment.
  ///
  /// In id, this message translates to:
  /// **'Metode pembayaran'**
  String get profile_payment;

  /// No description provided for @profile_safety.
  ///
  /// In id, this message translates to:
  /// **'Keamanan & SOS'**
  String get profile_safety;

  /// No description provided for @profile_language.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get profile_language;

  /// No description provided for @profile_help.
  ///
  /// In id, this message translates to:
  /// **'Bantuan'**
  String get profile_help;

  /// No description provided for @profile_switch_driver.
  ///
  /// In id, this message translates to:
  /// **'Beralih ke mode driver'**
  String get profile_switch_driver;

  /// No description provided for @profile_switch_driver_sub.
  ///
  /// In id, this message translates to:
  /// **'Hasilkan uang dengan RIHLAH'**
  String get profile_switch_driver_sub;

  /// No description provided for @profile_switch_passenger.
  ///
  /// In id, this message translates to:
  /// **'Beralih ke mode penumpang'**
  String get profile_switch_passenger;

  /// No description provided for @profile_switch_passenger_sub.
  ///
  /// In id, this message translates to:
  /// **'Pesan perjalanan'**
  String get profile_switch_passenger_sub;

  /// No description provided for @profile_sign_out.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get profile_sign_out;

  /// No description provided for @doc_section_label.
  ///
  /// In id, this message translates to:
  /// **'DOKUMEN'**
  String get doc_section_label;

  /// No description provided for @settings_section_label.
  ///
  /// In id, this message translates to:
  /// **'PENGATURAN'**
  String get settings_section_label;

  /// No description provided for @driver_since.
  ///
  /// In id, this message translates to:
  /// **'Driver sejak'**
  String get driver_since;

  /// No description provided for @driver_home_welcome.
  ///
  /// In id, this message translates to:
  /// **'Selamat datang kembali,'**
  String get driver_home_welcome;

  /// No description provided for @driver_home_earnings.
  ///
  /// In id, this message translates to:
  /// **'Pendapatan hari ini'**
  String get driver_home_earnings;

  /// No description provided for @driver_home_online.
  ///
  /// In id, this message translates to:
  /// **'Online'**
  String get driver_home_online;

  /// No description provided for @driver_home_offline.
  ///
  /// In id, this message translates to:
  /// **'Offline'**
  String get driver_home_offline;

  /// No description provided for @driver_home_go_online.
  ///
  /// In id, this message translates to:
  /// **'Mulai bertugas'**
  String get driver_home_go_online;

  /// No description provided for @driver_home_go_offline.
  ///
  /// In id, this message translates to:
  /// **'Berhenti bertugas'**
  String get driver_home_go_offline;

  /// No description provided for @driver_home_visible.
  ///
  /// In id, this message translates to:
  /// **'Kamu terlihat'**
  String get driver_home_visible;

  /// No description provided for @incoming_title.
  ///
  /// In id, this message translates to:
  /// **'Pesanan baru di sekitarmu'**
  String get incoming_title;

  /// No description provided for @incoming_from_you.
  ///
  /// In id, this message translates to:
  /// **'dari kamu'**
  String get incoming_from_you;

  /// No description provided for @incoming_will_earn.
  ///
  /// In id, this message translates to:
  /// **'Kamu akan mendapat'**
  String get incoming_will_earn;

  /// No description provided for @incoming_total_trip.
  ///
  /// In id, this message translates to:
  /// **'Total perjalanan'**
  String get incoming_total_trip;

  /// No description provided for @incoming_accept.
  ///
  /// In id, this message translates to:
  /// **'Terima'**
  String get incoming_accept;

  /// No description provided for @incoming_pass.
  ///
  /// In id, this message translates to:
  /// **'Lewati'**
  String get incoming_pass;

  /// No description provided for @incoming_expired.
  ///
  /// In id, this message translates to:
  /// **'Pesanan kadaluarsa'**
  String get incoming_expired;

  /// No description provided for @driver_trip_picking_up.
  ///
  /// In id, this message translates to:
  /// **'Menjemput'**
  String get driver_trip_picking_up;

  /// No description provided for @driver_trip_waiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu penumpang'**
  String get driver_trip_waiting;

  /// No description provided for @driver_trip_dropping.
  ///
  /// In id, this message translates to:
  /// **'Mengantar'**
  String get driver_trip_dropping;

  /// No description provided for @driver_trip_arrived.
  ///
  /// In id, this message translates to:
  /// **'Saya sudah tiba'**
  String get driver_trip_arrived;

  /// No description provided for @driver_trip_start.
  ///
  /// In id, this message translates to:
  /// **'Mulai perjalanan'**
  String get driver_trip_start;

  /// No description provided for @driver_trip_pickup_label.
  ///
  /// In id, this message translates to:
  /// **'PENJEMPUTAN'**
  String get driver_trip_pickup_label;

  /// No description provided for @driver_trip_passenger_way.
  ///
  /// In id, this message translates to:
  /// **'dalam perjalanan'**
  String get driver_trip_passenger_way;

  /// No description provided for @driver_trip_in_banner.
  ///
  /// In id, this message translates to:
  /// **'Dalam perjalanan · menuju tujuan'**
  String get driver_trip_in_banner;

  /// No description provided for @collect_title.
  ///
  /// In id, this message translates to:
  /// **'Terima pembayaran'**
  String get collect_title;

  /// No description provided for @collect_total_fare.
  ///
  /// In id, this message translates to:
  /// **'Total tarif'**
  String get collect_total_fare;

  /// No description provided for @collect_cash.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran tunai'**
  String get collect_cash;

  /// No description provided for @collect_platform_fee.
  ///
  /// In id, this message translates to:
  /// **'Biaya platform (20%)'**
  String get collect_platform_fee;

  /// No description provided for @collect_your_earn.
  ///
  /// In id, this message translates to:
  /// **'Pendapatanmu'**
  String get collect_your_earn;

  /// No description provided for @collect_mark_paid.
  ///
  /// In id, this message translates to:
  /// **'Tandai sudah dibayar'**
  String get collect_mark_paid;

  /// No description provided for @collect_saving.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan…'**
  String get collect_saving;

  /// No description provided for @collect_earned.
  ///
  /// In id, this message translates to:
  /// **'Kamu dapat'**
  String get collect_earned;

  /// No description provided for @collect_trip_ended.
  ///
  /// In id, this message translates to:
  /// **'Perjalanan selesai di Trans Studio Bandung'**
  String get collect_trip_ended;

  /// No description provided for @earnings_title.
  ///
  /// In id, this message translates to:
  /// **'Pendapatan'**
  String get earnings_title;

  /// No description provided for @earnings_today.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get earnings_today;

  /// No description provided for @earnings_week.
  ///
  /// In id, this message translates to:
  /// **'Minggu'**
  String get earnings_week;

  /// No description provided for @earnings_month.
  ///
  /// In id, this message translates to:
  /// **'Bulan'**
  String get earnings_month;

  /// No description provided for @earnings_withdraw.
  ///
  /// In id, this message translates to:
  /// **'Tarik ke rekening'**
  String get earnings_withdraw;

  /// No description provided for @earnings_breakdown.
  ///
  /// In id, this message translates to:
  /// **'Rincian'**
  String get earnings_breakdown;

  /// No description provided for @earnings_base.
  ///
  /// In id, this message translates to:
  /// **'Tarif dasar'**
  String get earnings_base;

  /// No description provided for @earnings_surge.
  ///
  /// In id, this message translates to:
  /// **'Surge'**
  String get earnings_surge;

  /// No description provided for @earnings_tips.
  ///
  /// In id, this message translates to:
  /// **'Tips'**
  String get earnings_tips;

  /// No description provided for @earnings_recent.
  ///
  /// In id, this message translates to:
  /// **'PERJALANAN TERBARU'**
  String get earnings_recent;

  /// No description provided for @earnings_label_today.
  ///
  /// In id, this message translates to:
  /// **'Total pendapatan hari ini'**
  String get earnings_label_today;

  /// No description provided for @earnings_label_week.
  ///
  /// In id, this message translates to:
  /// **'Total pendapatan minggu ini'**
  String get earnings_label_week;

  /// No description provided for @earnings_label_month.
  ///
  /// In id, this message translates to:
  /// **'Total pendapatan bulan ini'**
  String get earnings_label_month;

  /// No description provided for @history_title.
  ///
  /// In id, this message translates to:
  /// **'Riwayat'**
  String get history_title;

  /// No description provided for @history_all.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get history_all;

  /// No description provided for @history_today.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get history_today;

  /// No description provided for @history_this_week.
  ///
  /// In id, this message translates to:
  /// **'Minggu ini'**
  String get history_this_week;

  /// No description provided for @history_empty_title.
  ///
  /// In id, this message translates to:
  /// **'Belum ada perjalanan'**
  String get history_empty_title;

  /// No description provided for @history_empty_body.
  ///
  /// In id, this message translates to:
  /// **'Selesaikan perjalanan untuk melihat riwayatmu'**
  String get history_empty_body;

  /// No description provided for @history_go_online.
  ///
  /// In id, this message translates to:
  /// **'Mulai berkendara'**
  String get history_go_online;

  /// No description provided for @sos_triggered.
  ///
  /// In id, this message translates to:
  /// **'SOS diaktifkan'**
  String get sos_triggered;

  /// No description provided for @sos_help_way.
  ///
  /// In id, this message translates to:
  /// **'Bantuan sedang dalam perjalanan'**
  String get sos_help_way;

  /// No description provided for @sos_sharing.
  ///
  /// In id, this message translates to:
  /// **'Membagikan lokasi live ke kontak terpercaya'**
  String get sos_sharing;

  /// No description provided for @sos_call_police.
  ///
  /// In id, this message translates to:
  /// **'Hubungi polisi 110'**
  String get sos_call_police;

  /// No description provided for @sos_call_sub.
  ///
  /// In id, this message translates to:
  /// **'Sambungan langsung ke darurat lokal'**
  String get sos_call_sub;

  /// No description provided for @sos_share_contacts.
  ///
  /// In id, this message translates to:
  /// **'Bagikan ke kontak terpercaya'**
  String get sos_share_contacts;

  /// No description provided for @sos_share_sub.
  ///
  /// In id, this message translates to:
  /// **'Lokasi live selama 30 menit'**
  String get sos_share_sub;

  /// No description provided for @sos_cancel.
  ///
  /// In id, this message translates to:
  /// **'Batalkan SOS'**
  String get sos_cancel;

  /// No description provided for @sos_share_title.
  ///
  /// In id, this message translates to:
  /// **'Berbagi lokasi'**
  String get sos_share_title;

  /// No description provided for @sos_share_body.
  ///
  /// In id, this message translates to:
  /// **'Lokasi live selama 30 menit ke kontak terpercaya:'**
  String get sos_share_body;

  /// No description provided for @common_cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get common_cancel;

  /// No description provided for @common_confirm.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi'**
  String get common_confirm;

  /// No description provided for @common_close.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get common_close;

  /// No description provided for @common_save.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get common_save;

  /// No description provided for @common_edit.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get common_edit;

  /// No description provided for @common_coming_soon.
  ///
  /// In id, this message translates to:
  /// **'Segera hadir'**
  String get common_coming_soon;

  /// No description provided for @searchingLooking.
  ///
  /// In id, this message translates to:
  /// **'Mencari driver terdekat…'**
  String get searchingLooking;

  /// No description provided for @searchingAlmost.
  ///
  /// In id, this message translates to:
  /// **'Hampir ada…'**
  String get searchingAlmost;

  /// No description provided for @searchingHang.
  ///
  /// In id, this message translates to:
  /// **'Tunggu sebentar…'**
  String get searchingHang;

  /// No description provided for @searchingMatching.
  ///
  /// In id, this message translates to:
  /// **'Sedang mencarikan driver untukmu'**
  String get searchingMatching;

  /// No description provided for @searchingCancel.
  ///
  /// In id, this message translates to:
  /// **'Batalkan pesanan'**
  String get searchingCancel;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In id, this message translates to:
  /// **'Batalkan pesanan?'**
  String get cancelOrderTitle;

  /// No description provided for @cancelOrderBody.
  ///
  /// In id, this message translates to:
  /// **'Kamu tidak akan dikenakan biaya. Driver akan diberitahu.'**
  String get cancelOrderBody;

  /// No description provided for @cancelYes.
  ///
  /// In id, this message translates to:
  /// **'Ya, batalkan'**
  String get cancelYes;

  /// No description provided for @cancelKeep.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan pesanan'**
  String get cancelKeep;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
