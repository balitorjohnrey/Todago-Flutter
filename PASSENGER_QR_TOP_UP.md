# Passenger QR top-ups (Android version 1.0.0+4)

Install `D:\todago\TodaGo-QRPh-passenger-pool-v4.apk` over the previous build.
The signing certificate matches version 3, so an uninstall is unnecessary.

1. Sign in and open Wallet, then Top Up.
2. Top-Up Now opens the passenger's permanently assigned QR on the separate
   hosted QR site inside TodaGo. No amount or receipt-reference field is shown.
3. Download QR saves the unmodified, checksum-verified JPEG to Photos/Pictures
   under TodaGo. Select that image in GCash, Maya or a participating bank app.
4. Enter the amount and complete payment there. The backend verifies the live
   PayMongo `payment.paid` webhook and credits the QR owner at the amount paid.
5. TodaGo refreshes its own server state every five seconds and on resume.
   Confirmation can return automatically to the wallet; Done also returns there.
   Done, Back and switching apps never create a credit themselves.

An empty pool displays that a QR is being prepared. Adding more stock to the
backend and QR site does not require rebuilding this Android app. Each new code
must be hosted and included in the site's allowlist before the backend imports it.

The top-up implementation does not access PayMongo API keys. Historical shared-QR
records remain supported separately, including the audited recovery of the old
payment. Retired local preview preferences are still cleared by wallet_migration;
they never affect the displayed server balance.

Tests: `flutter test test/passenger_qr_pool_test.dart test/passenger_wallet_top_up_test.dart test/merchant_qr_top_up_test.dart`.
The former `passenger_demo_wallet_test.dart` integration test was updated for
this real-payment flow and renamed to `passenger_wallet_top_up_test.dart`.

Automated checks and the release build passed. Physical-device Photos visibility
and the first payment using a newly assigned pool QR still require owner testing.
