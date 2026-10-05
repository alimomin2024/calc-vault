# Privacy Policy for CalcVault

**Last updated:** October 5, 2026

**CalcVault: Secret Calculator & Photo Locker** ("CalcVault", "we", "our", or "the app") is developed with a strict **privacy-first, offline-by-design** philosophy. We believe your private data, memories, and documents should remain exclusively yours.

This Privacy Policy explains how CalcVault handles information on your device and confirms our commitment to collecting zero personal data.

---

## 1. Summary of Core Principles

- **100% Offline**: CalcVault contains **no network permissions** in release builds (`android.permission.INTERNET` is explicitly stripped). The app cannot connect to the internet, cloud servers, or external services.
- **No Data Collection**: We do not collect, store, transmit, or sell any personal data, identifiers, usage analytics, or diagnostic telemetry.
- **On-Device AES-256 Encryption**: All photos, videos, notes, passwords, and metadata are encrypted locally using authenticated AES-256-GCM.
- **Zero Third-Party SDKs**: No advertising networks, tracking libraries, social sign-ins, or telemetry tools are bundled.

---

## 2. Information Handled On Your Device

All operations performed by CalcVault happen strictly on your local device. We never have access to your encryption keys, PINs, or files.

### A. Your Master & Decoy PINs
- Your master and decoy PINs are never stored in plaintext.
- PINs are used to derive 256-bit encryption keys via a salted **PBKDF2-HMAC-SHA256** key derivation function (120,000 iterations).
- Wrapped keys and verification salts are stored securely in Android's hardware-backed **Keystore**.

### B. Encrypted Media & Records
- Photos, videos, documents, and credentials that you import into CalcVault are encrypted with **AES-256-GCM** using unique 96-bit nonces.
- Decrypted media is held only temporarily in volatile memory (RAM) while being viewed and is purged immediately upon closing, locking, or backgrounding the app.

---

## 3. Device Permissions & How They Are Used

CalcVault requests only the minimum device permissions necessary to perform its core offline vault functionality. Each permission is strictly opt-in and handled on-device:

| Permission | Purpose | Network Usage |
| :--- | :--- | :--- |
| **Photos / Media Access** (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`) | Allows you to select photos and videos to import and encrypt within your vault. | **None (Offline)** |
| **Camera** (`android.permission.CAMERA`) | *(Optional / Opt-in)* Used solely for the **Break-In Intruder Selfie** feature to capture an image when consecutive wrong PINs are entered. | **None (Offline)** |
| **Microphone / Audio** (`RECORD_AUDIO`) | *(Optional / Opt-in)* Used solely if you choose to record private voice memos directly within the vault. | **None (Offline)** |
| **Sensors** (`sensors_plus`) | Accesses the device accelerometer solely for the **Panic Flip** feature to detect when the phone is flipped face-down to immediately lock the app. | **None (Offline)** |

---

## 4. Third-Party Sharing and Disclosures

Because CalcVault is completely offline and does not collect any data:
- **No Third-Party Sharing**: We do not share, sell, rent, or monetize your data with any third parties.
- **No Cloud Sync or Backups**: Your vault files reside solely in your device's protected internal storage. CalcVault explicitly opts out of automated OS cloud backups to avoid leaking encrypted blobs to third-party cloud drives.

---

## 5. Security & Anti-Snoop Measures

- **FLAG_SECURE**: CalcVault enables Android's `FLAG_SECURE` window flag, preventing unauthorized screenshots, screen recording, and exposure in recent task-switcher thumbnails.
- **Decoy Vault System**: A secondary Decoy PIN unlocks an isolated, harmless vault environment under duress without revealing the existence of your primary files.
- **Instant Memory Purge**: Switching apps, receiving a phone call, or flipping your device face-down immediately purges private state from memory.

---

## 6. Children's Privacy (COPPA)

CalcVault does not collect any personal information from any user, including children under the age of 13. The application is completely offline and safe for general audiences.

---

## 7. Data Retention & Deletion

You have complete control over your data:
- You may permanently delete any photo, video, record, or folder directly inside the vault at any time.
- Deleting or uninstalling the app permanently purges all local encrypted vault files and keys from the device. Because there are no cloud backups or remote servers, uninstalled or lost data cannot be recovered.

---

## 8. Changes to This Privacy Policy

If we update this Privacy Policy, the revised version will be posted here with an updated "Last updated" date.

---

## 9. Contact Us

If you have questions, feedback, or concerns regarding this Privacy Policy or CalcVault's security practices, please contact:

- **Developer:** CalcVault Security Team
- **Email:** support@calcvault.app *(or contact via GitHub repository: [github.com/alimomin2024/calc-vault](https://github.com/alimomin2024/calc-vault))*
