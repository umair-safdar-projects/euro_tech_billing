# Lifetime activation

Euro Tech Billing uses a one-time, offline activation for the licensed company computer.

## Customer activation

1. Build and install the application.
2. Open **Settings → Lifetime activation**.
3. Copy the displayed **Computer code** and send it to the vendor with the company name.
4. Paste the returned activation code into the same screen and select **Activate software**.

The activation has no expiry date and is stored in the Windows application-support folder, outside the installation directory. Reinstalling or upgrading the application does not normally remove it. A replacement laptop receives a new computer code and requires a manual re-issue.

While unactivated, existing records, reports, backups, and PDF exports remain available, but saving a new invoice or saving an invoice correction is blocked.

## Vendor key generation

Run this command from the repository on the vendor development machine:

```text
dart run tool/generate_lifetime_license.dart "EURO TECH EDGING AND CUTTING" ABCDEF0123456789
```

Replace the final argument with the customer's 16-character computer code. Never publish a customer's activation code in the repository.

This is an offline activation deterrent, not tamper-proof DRM: an experienced person with access to the application binary could bypass a local check. Keep the signed agreement and payment record as the commercial source of truth. Stronger enforcement would require an online licensing service and its ongoing hosting cost.
