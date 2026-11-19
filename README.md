# todago_flutter

## FAQ knowledge base

The chatbot includes 100 role-aware FAQ entries adapted from online FAQ/help
collections, with direct source links, APA citations, and review dates. Each
matched answer has a Sources button. The canonical content is maintained in
`../todago_backend/src/data/faqs.json` and `faq_online_sources.json`;
`lib/data/faq_dataset.g.dart` is their
generated offline copy. From the backend directory, run `npm run faq:sync`
after editing the JSON and `npm run faq:check` to check parity. See
[FAQ dataset and sources](../todago_backend/FAQ_DATASET.md) for provenance,
matching behavior, and validation commands. The app's quick questions include
**Where do the FAQ answers come from?** for every role.

The [APA bibliography](../todago_backend/docs/FAQ_REFERENCES_APA.md),
[per-question source map](../todago_backend/docs/FAQ_SOURCE_MAP.md), and
[CSV dataset](../todago_backend/docs/faq_dataset.csv) are generated with the
Flutter copy. External providers' fees, deadlines, and policies are not adopted
as TodaGo rules.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Mobile push notifications

TodaGo's API runs on Railway. PostgreSQL stores trips, push device registrations,
and queued alerts. Firebase Cloud Messaging (FCM) delivers the notifications to
phones. Use the same Firebase project for the mobile app and the backend's FCM
credentials.

1. Create a project in the [Firebase console](https://console.firebase.google.com/)
   and enable the [Firebase Cloud Messaging API](https://firebase.google.com/docs/cloud-messaging/send/v1-api).
2. In Firebase, open **Project settings → Service accounts → Generate new private key**.
   On the Railway **backend service**, add `FCM_SERVICE_ACCOUNT_JSON` under
   **Variables** with the entire contents of that JSON file. Keep the key in
   Railway's private variables. Deploy the backend revision that contains push
   support. The backend creates the push tables in the existing PostgreSQL
   database on startup. `TODAGO_PICKUP_PUSH_RADIUS_METERS` defaults to 300 meters
   of straight-line distance from the pickup point.
3. Register the Android app `com.example.todago_flutter` in Firebase. Place its
   `google-services.json` in `android/app/`, then run
   `flutter build apk --release` with Flutter 3.50.
4. For iOS, register the bundle identifier used to sign Runner
   (`com.example.todagoFlutter` by default). Add `GoogleService-Info.plist` to the
   Runner target in Xcode, enable the Push Notifications capability, and upload
   the APNs key in Firebase. Follow the
   [Firebase Apple setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
5. Install the configured app on test phones, sign in, and allow notifications.
   Book a ride from the passenger phone. After the driver accepts, switch the
   passenger phone to another app while the driver approaches the pickup point.
   Expect a **Your driver is nearby** banner on the passenger phone once the
   driver's GPS is within range. Check that further GPS updates do not repeat the
   alert and that unrelated accounts receive nothing.

Use Android's **TodaGo updates** notification channel with pop-up banners
enabled, or enable **Banners** for TodaGo in iOS notification settings.
