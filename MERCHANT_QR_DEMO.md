# Merchant QR Ph top-up

The local fake-credit implementation has been retired. The app now reads only
the backend wallet balance. On startup it removes the old local preview wallet
preference keys; accounts, rides and unrelated preferences are preserved.

Passengers enter their own amount, including centavos. Preset amount buttons
have been removed. The backend enforces PHP 20–50,000 and exact centavos.

Top-Up Now creates/reuses a pending backend request and opens the separate
public QR page inside the app:

https://todago-qrph.johnmejio11.chatgpt.site/

The website retains the original QR image, a white background and a blue Done
button with white text. Done only returns to the receipt-reference form.
Submitting a reference or returning from another app never adds local funds.
The backend completes the top-up only after matching the receipt to a signed
live payment for the configured merchant QR and exact amount. Either arrival
order is supported; duplicates cannot add another credit.

Pending payments can be reopened from wallet history. The app checks its own
backend status every five seconds while the reference screen is open, on resume
and when refreshing. It does not poll PayMongo or require a live API key.

Real top-ups remain unavailable until the backend is deployed with the verified
merchant QR ID and the dedicated live webhook signing secret. The prepared
wallet reset runs once during an approved backend deployment, retaining an
audit backup and historical ride payment records.

See [backend setup](../todago_backend/INSTORE_QR_SETUP.md) for the exact endpoint,
Railway variables, reset behavior and remaining live acceptance checks.
Install the rebuilt APK with version code **3** for this flow.
