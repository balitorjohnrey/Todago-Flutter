# Merchant QR and demo top-up

New passenger top-ups open the bundled merchant QR directly. This screen does
not call `/payment-methods`, create a PayMongo Payment Intent, generate a new QR,
or open a WebView. A test API key does not affect this display.

The unmodified uploaded image is `assets/payments/todago_in_store_qrph.jpg`,
for merchant QR `qr_be9cd139efbb7b6632b31e6f`. Its SHA-256 is
`0620cd96f2d345fbfc359b80f0c8821f185bdcb39a46afc11b51607427d366da`.
The existing `assets/payments/` pubspec entry bundles it. The page supports
full-size viewing, pinch zoom and copying the selected amount.

Demo flow:

1. Open Wallet > Top Up and choose PHP 20, 50, 100, 200, 500 or 1,000.
2. Tap Proceed to Top Up to preview the QR.
3. Tap **Top-Up Now**. No scan or real payment is required.
4. The passenger wallet displays Demo Wallet Balance and Demo Transaction History.
5. Reset demo wallet removes the local demo funds and restores the confirmed
   backend balance/history display.

On the QR preview, **Auto-finish demo on return** is enabled initially. Leaving
TodaGo for another app and returning closes the preview and adds the chosen
demo amount once. It also works from the full-size QR viewer. An inactive-only
transition (such as an overlay) does not finish the demo. The switch can disable
this behavior. App resumption is a demo trigger, never payment verification.

Demo funds are stored locally using SharedPreferences, under a separate key per
authenticated passenger ID. Real wallet summaries cannot overwrite the demo
balance. Demo credits never enter the backend ledger and do not authorize real
ride spending, cash-outs or transfers. Closing the page or just viewing the QR
does not create a demo credit. Existing payment history can still reopen its
original provider checkout; it is not the new merchant QR top-up flow.

The displayed merchant QR remains a REAL payment QR. Paying it through GCash,
Maya or a bank moves real money and does not automatically credit this demo
wallet. The screen states this before the QR, separately from Top-Up Now.

This change needs a rebuilt/installed Flutter app. No Railway variable or API
key change is required for the merchant QR/demo screen. The older backend
passenger-static-QR implementation remains available separately; its configuration
does not select this new Flutter flow.
