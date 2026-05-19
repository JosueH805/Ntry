# Ntry — Developer Bible

> **The single source of truth for the Ntry Smart Dorm Access System.**
> If you're new to the project, read this top to bottom before touching any code.
> If you're a returning dev, use the table of contents to jump to what you need.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [The Big Picture — How It All Fits Together](#2-the-big-picture--how-it-all-fits-together)
3. [Tech Stack (Definitive)](#3-tech-stack-definitive)
4. [Repository Structure](#4-repository-structure)
5. [User Roles & Personas](#5-user-roles--personas)
6. [Core Feature Flows](#6-core-feature-flows)
   - 6.1 [BLE Proximity Unlock (Walk-Up Entry)](#61-ble-proximity-unlock-walk-up-entry)
   - 6.2 [Manual App Unlock](#62-manual-app-unlock)
   - 6.3 [Guest Pass Generation & QR Entry](#63-guest-pass-generation--qr-entry)
   - 6.4 [Admin Force Unlock](#64-admin-force-unlock)
   - 6.5 [Device Registration & Revocation](#65-device-registration--revocation)
   - 6.6 [Auto-Relock](#66-auto-relock)
7. [Security Model](#7-security-model)
8. [Cloud Infrastructure (GCP + Firebase)](#8-cloud-infrastructure-gcp--firebase)
9. [Hardware — M5Stack CoreS3 (ESP32S3)](#9-hardware--m5stack-cores3-esp32s3)
   - 9.1 [Device Overview](#91-device-overview)
   - 9.2 [Pin Mapping & Wiring](#92-pin-mapping--wiring)
   - 9.3 [Servo Motor & Mechanical Retrofit](#93-servo-motor--mechanical-retrofit)
   - 9.4 [Camera Module & QR Scanning](#94-camera-module--qr-scanning)
   - 9.5 [BLE Scanning on the ESP32S3](#95-ble-scanning-on-the-esp32s3)
   - 9.6 [MicroPython Firmware Notes](#96-micropython-firmware-notes)
10. [Mobile App — Flutter](#10-mobile-app--flutter)
    - 10.1 [Screen Map & Navigation](#101-screen-map--navigation)
    - 10.2 [BLE Advertising (Phone Side)](#102-ble-advertising-phone-side)
    - 10.3 [Biometric Lock](#103-biometric-lock)
    - 10.4 [UI Design Reference](#104-ui-design-reference)
    - 10.5 [Data Layer & State Management](#105-data-layer--state-management)
11. [Database Schema — Cloud Firestore](#11-database-schema--cloud-firestore)
12. [Environment Variables & Secrets](#12-environment-variables--secrets)
13. [Setup & Installation](#13-setup--installation)
    - 13.1 [Prerequisites](#131-prerequisites)
    - 13.2 [Firebase / GCP Setup](#132-firebase--gcp-setup)
    - 13.3 [Flutter App Setup](#133-flutter-app-setup)
    - 13.4 [M5Stack Firmware Setup](#134-m5stack-firmware-setup)
14. [Git Workflow & PR Process](#14-git-workflow--pr-process)
15. [Jira Workflow](#15-jira-workflow)
16. [Testing Strategy & Acceptance Criteria](#16-testing-strategy--acceptance-criteria)
17. [Known Bugs & Gotchas](#17-known-bugs--gotchas)
18. [Cool Features & Expansion Ideas](#18-cool-features--expansion-ideas)
19. [Team](#19-team)

---

## 1. Project Overview

**Ntry** is a smart dorm access system that replaces physical keys and RFID cards with a resident's smartphone. The system has three primary entry methods:

- **BLE Proximity (Walk-Up Entry):** The door unlocks automatically when the resident's phone is within ~2 feet. No interaction required.
- **Manual App Unlock:** A resident taps "Unlock" in the app to trigger the door remotely.
- **Guest QR Code:** A resident generates a time-limited QR code for a visitor. The visitor shows the QR to the door's camera to enter without the resident being present.

The physical unlock mechanism is a non-invasive retrofit — a servo motor lowers a cloned ID card onto the existing door card reader. No rewiring of the building is required.

**Why this matters:** Physical keys are lost, stolen, and forgotten constantly. Ntry makes smartphones the credential — they're harder to lose, come with biometric locks and GPS, and can be remotely revoked in seconds.

---

## 2. The Big Picture — How It All Fits Together

```
┌──────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                            │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐    │
│   │              Flutter Mobile App (iOS / Android)         │    │
│   │   - BLE Advertising (Service UUID broadcast)            │    │
│   │   - Manual Unlock Button                                │    │
│   │   - Guest Pass QR Generation                            │    │
│   │   - Biometric / PIN gate                                │    │
│   └──────────────┬─────────────────────────────────────────┘    │
│                  │  HTTPS (Firebase SDK)                         │
└──────────────────┼───────────────────────────────────────────────┘
                   │
┌──────────────────▼───────────────────────────────────────────────┐
│                         CLOUD LAYER                              │
│                                                                  │
│   ┌──────────────────────┐   ┌──────────────────────────────┐   │
│   │   Firebase Auth      │   │     Cloud Firestore (DB)     │   │
│   │   - Email/password   │   │   - users/                   │   │
│   │   - Google Sign-In   │   │   - devices/                 │   │
│   │   - JWT issuance     │   │   - guestPasses/             │   │
│   │   - Role management  │   │   - access_logs/             │   │
│   └──────────────────────┘   └───────────────┬──────────────┘   │
│   ┌──────────────────────────────────────────┐│                  │
│   │        Google Cloud IoT Core             ││                  │
│   │        (MQTT Broker / TLS)               ││                  │
│   │   - Publishes unlock commands            ││                  │
│   │   - Receives device telemetry            ││                  │
│   │   - OTA firmware delivery                ││                  │
│   └──────────────────────────┬───────────────┘│                  │
└────────────────────────────── ┼────────────────┼──────────────────┘
                                │ MQTT/TLS        │ Real-time listener
┌───────────────────────────────▼─────────────────▼────────────────┐
│                          EDGE LAYER                              │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐   │
│   │            M5Stack CoreS3 (ESP32S3) — MicroPython        │   │
│   │                                                          │   │
│   │   ┌────────────┐  ┌────────────┐  ┌──────────────────┐  │   │
│   │   │ BLE Scanner│  │ QR Camera  │  │  Servo Controller│  │   │
│   │   │ (ESP32 BT) │  │ (USB-C mod)│  │  (GPIO → Motor)  │  │   │
│   │   └─────┬──────┘  └─────┬──────┘  └────────┬─────────┘  │   │
│   │         │               │                   │             │   │
│   │         └───────────────┴──── Trigger ──────┘             │   │
│   │                        Cloud-verified unlock              │   │
│   └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│                  ┌───────────────────────┐                       │
│                  │   Servo Motor         │                       │
│                  │   → Lowers cloned     │                       │
│                  │     ID card onto      │                       │
│                  │     door reader       │                       │
│                  └───────────────────────┘                       │
└──────────────────────────────────────────────────────────────────┘
```

**Key design principle — Zero Local Trust:** The M5Stack never makes an access decision on its own. Every BLE detection, QR scan, or local button press triggers a cloud validation request first. The servo only moves after the cloud says yes. This prevents spoofing attacks where someone replicates a BLE UUID or presents an expired QR code.

---

## 3. Tech Stack (Definitive)

> The actual stack as of Sprint 3+ is GCP/Firebase. Any AWS references in older docs are deprecated and should be ignored.

| Layer | Technology | Notes |
|---|---|---|
| **Mobile App** | Flutter (Dart) | iOS + Android from one codebase |
| **Authentication** | Firebase Authentication | Email/password + Google Sign-In, JWT issuance, role-based routing |
| **Database** | Cloud Firestore (NoSQL) | Real-time listeners, rules-based security |
| **IoT Messaging** | Google Cloud IoT Core (MQTT/TLS) | Secure bi-directional channel to M5Stack |
| **Edge Controller** | M5Stack CoreS3 (ESP32S3) | MicroPython firmware |
| **Navigation** | go_router | Declarative routing with role-based redirects |
| **QR Generation** | qr_flutter | QR code display for guest passes |
| **BLE (Phone side)** | flutter_blue_plus *(planned)* | Will advertise unique Service UUID |
| **BLE (Door side)** | ESP32S3 onboard BT radio | Scans for authorized UUIDs |
| **Camera / QR** | USB-C camera module + M5Stack | OpenCV-style decode in MicroPython |
| **Servo / GPIO** | High-torque servo wired to M5Stack GPIO | Lowers/raises cloned ID card |
| **Card Cloning** | Flipper Zero | MIFARE Classic 1K dorm card clone |
| **OTA Updates** | Google Cloud IoT Core device mgmt | Patch firmware without physical access |
| **Typography** | google_fonts (Inter) | Inter font throughout the app |
| **UI Design** | Figma | See link in §10.4 |
| **Project Mgmt** | Jira + Git (GitHub) | Epics per user story, see §14–15 |

---

## 4. Repository Structure

The project is split across **three separate repositories** under the `Ntry-SAS` GitHub organization:

| Repository | Purpose |
|---|---|
| **ntry_mobile** | Flutter mobile app (iOS + Android) |
| **ntry_edge** | M5Stack MicroPython firmware |
| **ntry_backend** | Cloud Functions, Firestore rules, backend scripts |

Each repository follows the same branching strategy (`main` → `staging` → feature branches). See §14 for the full Git workflow.

---

### ntry_mobile

```
ntry_mobile/
├── lib/
│   ├── main.dart                   # App entry point, Firebase init, singletons
│   ├── auth/
│   │   └── auth_service.dart       # Firebase auth wrapper — also caches firstName, lastName, organization
│   ├── database/                   # Firestore helpers — one class per collection
│   │   ├── user_helper.dart        # CRUD + stream ops for users/
│   │   ├── lock_helper.dart        # CRUD + stream ops for locks/; unlock() / relock()
│   │   ├── location_helper.dart    # CRUD + stream ops for locations/
│   │   └── guest_helper.dart       # CRUD + stream ops for locks/{id}/guests subcollection
│   ├── providers/                  # Live-streaming ChangeNotifiers (global singletons)
│   │   ├── user_provider.dart      # Streams users/{uid} → exposes all profile fields
│   │   └── lock_provider.dart      # Streams locks/{lockId} → exposes room, status, unlocked
│   ├── routing/
│   │   └── app_router.dart         # GoRouter config with role-based redirects
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   └── pending_approval_screen.dart
│   │   ├── guest/
│   │   │   ├── guest_code_screen.dart
│   │   │   └── guest_qr_screen.dart
│   │   ├── resident/
│   │   │   ├── resident_home_screen.dart
│   │   │   ├── activity_screen.dart
│   │   │   ├── guest_management_screen.dart
│   │   │   ├── device_settings_screen.dart
│   │   │   └── profile_screen.dart
│   │   └── admin/
│   │       ├── admin_home_screen.dart
│   │       ├── manage_users_screen.dart
│   │       ├── access_log_screen.dart
│   │       ├── lock_management_screen.dart
│   │       ├── add_lock_screen.dart
│   │       ├── lock_detail_screen.dart
│   │       ├── location_management_screen.dart
│   │       ├── add_location_screen.dart
│   │       └── location_detail_screen.dart
│   ├── widgets/
│   │   ├── lock_form_widgets.dart      # Shared form primitives for lock add/edit
│   │   ├── location_form_widgets.dart  # Shared form primitives for location add/edit
│   │   ├── lock_status_card.dart       # Live lock status display card
│   │   ├── lock_access_list.dart       # User access list + remove tile
│   │   ├── lock_add_user_sheet.dart    # Bottom sheet to assign a user to a lock
│   │   ├── search_picker_sheet.dart    # Generic searchable bottom-sheet picker
│   │   └── access_log_view.dart        # Shared access log stream + tile renderer (used by admin & resident)
│   ├── theme/
│   │   ├── app_colors.dart         # Color palette constants
│   │   ├── app_theme.dart          # MaterialApp theme definitions
│   │   ├── theme_extensions.dart
│   │   └── theme_notifier.dart     # ChangeNotifier for theme switching
│   └── firebase_options.dart       # Auto-generated Firebase config
├── android/
├── ios/
└── pubspec.yaml
```

---

### ntry_edge

```
ntry_edge/
├── main.py                 # Entry point — starts all services
├── ble_scanner.py          # Scans for authorized BLE UUIDs
├── qr_scanner.py           # Camera capture + QR decode
├── servo_controller.py     # GPIO servo driver (lock/unlock/relock)
├── mqtt_client.py          # Google Cloud IoT Core MQTT connection
├── cloud_validator.py      # Sends validation requests, awaits response
├── touchscreen_ui.py       # Local M5Stack display + override button
├── ota_updater.py          # OTA firmware update handler
├── config.py               # Device ID, MQTT topics, GPIO pin constants
└── secrets.py              # NOT committed — Wi-Fi, MQTT key (see §12)
```

---

### ntry_backend

```
ntry_backend/
├── functions/              # Firebase Cloud Functions
├── firestore.rules         # Firestore security rules
└── docs/                   # Supporting documentation
    ├── architecture.png
    ├── screen-flowchart.png
    ├── wiring-diagram.png
    └── SWPP.docx
```

---

## 5. User Roles & Personas

Ntry has three distinct user roles. Each role has a separate navigation experience in the app and different permissions in Firestore.

**Resident** — The primary user. A student living in the dorm. They can unlock their own door (manually or via proximity), generate guest passes, register their device, and revoke guest passes they've issued.

**Admin** — Building staff or an RA. They can view all residents, manage which devices are authorized, see the full access log, and issue emergency remote lock/unlock commands. Admins self-sign-up like residents, but must be approved by an existing approved admin in their organization (or manually approved in the Firebase Console for the first admin of a new org).

**Guest** — A visitor with no app account. They receive a one-time entry code from a Resident via the share sheet. They enter the code on the auth screen to reach a full-screen QR code display. They scan that QR at the door camera. That's the entirety of their experience — simple and secure by design.

Role is stored as a string field (`"resident"` or `"admin"`) on the Firestore `users/{uid}` document and is used for routing immediately after login.

---

## 6. Core Feature Flows

### 6.1 BLE Proximity Unlock (Walk-Up Entry)

This is the marquee feature — the resident walks up to the door with their phone in their pocket and the door unlocks. Here is exactly how it works end to end.

**Phone side:** The Flutter app runs a background BLE advertising service using `flutter_blue_plus`. It broadcasts a custom BLE Service UUID that is unique to the resident's device. This UUID is generated when the resident registers their device in their profile and is stored in Firestore under `devices/{deviceId}`. The app does not need to be open for this to work — the BLE service runs in the background.

**Door side:** The M5Stack CoreS3 continuously scans for BLE advertisements via its onboard ESP32S3 radio. It maintains an in-memory cache of authorized UUIDs pulled from Firestore at startup (and refreshed periodically). When a UUID is detected with an RSSI above the threshold (~2 ft range, roughly -65 dBm), it does **not** immediately unlock. Instead, it fires a cloud validation request.

**Cloud validation:** The M5Stack sends the detected UUID and the resident's JWT to a Firestore callable or publishes a validation request via MQTT to Google Cloud IoT Core. The cloud checks: (1) Does this UUID exist in `devices/`? (2) Is the `isRevoked` flag false? (3) Is the associated user account active? If all checks pass, the cloud publishes an `unlock` command back to the M5Stack over MQTT/TLS.

**Physical action:** On receiving the MQTT unlock command, `servo_controller.py` drives the servo to lower the cloned ID card onto the door reader. Two seconds later, `auto_relock()` is called and the servo retracts the card. The event is written to `access_logs/` with `method: "BLE"`, the resident's display name as `visitor_name`, and a UTC timestamp.

```
Phone BLE broadcast
    → M5Stack detects UUID + RSSI threshold
    → M5Stack sends validation request (MQTT) to Cloud IoT Core
    → Cloud checks Firestore devices/ and users/
    → Cloud publishes unlock command (MQTT/TLS) to M5Stack
    → Servo lowers card (unlock)
    → 2 seconds → servo raises card (relock)
    → access_logs/ entry written
```

**Key acceptance criterion:** Door unlocks within 3 seconds when the user stands within 2 feet of the sensor.

---

### 6.2 Manual App Unlock

The resident opens the app, passes biometric/PIN auth, and taps the large "Unlock" button on the home screen.

The button triggers a write to **Firebase RTDB** at `locks/{lockId}/pendingCommand` (singular) with `{ command: "unlock", requestedBy: uid, status: "pending", logId }`. The M5Stack has a real-time RTDB stream listener (`setStreamCallback`) running on a dedicated FreeRTOS task — it fires the servo the instant the data arrives (~100–200ms). A Firestore fallback path (`locks/{lockId}/pendingCommands/{commandId}` subcollection, ~500ms poll) is available via a compile-time flag (`USE_RTDB 0` in firmware, `_useRtdb = false` in `LockHelper`).

The app first writes an `access_logs/` entry (status `"pending"`) to create an audit record, then writes the RTDB node with the `logId` embedded. The app optimistically assumes success and turns the button green after 1 second (as long as the RTDB write itself succeeded). The M5Stack fires the servo, updates `access_logs/{logId}` to `status: "executed"`, and deletes the RTDB node. If the log stream returns `status: "failed"` within that 1-second window, the app reverts and shows an error.

```
Resident taps Unlock (post-biometric)
    → App writes access_logs/ entry (status: "pending")
    → App writes locks/{lockId}/pendingCommand (RTDB) with logId
    → App unlock button enters loading state (orange)
    → [~100ms] M5Stack RTDB stream callback fires
    → Servo lowers card
    → 2 seconds → auto-relock
    → M5Stack updates access_logs/{logId} (status: "executed")
    → M5Stack deletes RTDB pendingCommand node
    → [~1s after write] App optimistically turns green
      (reverts if log stream returns status: "failed" first)
```

---

### 6.3 Guest Pass Generation & QR Entry

**Generation (Resident side):** The resident navigates to Guest Management → Create Guest Pass and fills in a visitor name and expiry time. The app generates a signed JWT containing `{ guestPassId, lockId, expiresAt }`. This token is stored as a new document in `guestPasses/{passId}` with fields: `token`, `createdBy` (resident UID), `visitorName`, `expiresAt`, `isRevoked: false`. The QR code displayed on screen encodes only the `guestPassId` string — not the full JWT — so the raw QR cannot be decoded to reveal sensitive token content without the server.

**Sharing:** Residents can export the QR as an image via the iOS/Android share sheet.

**Guest entry flow:** The visitor receives a one-time code (separate from the QR — this is the code they enter on the auth screen to *display* the QR). They enter that code → they see the full-screen QR with a countdown timer. They hold this up to the M5Stack's camera at the door.

**Camera decode & validation:** The USB-C camera module continuously captures frames. `qr_scanner.py` decodes frames looking for a QR payload. On decode, it extracts the `guestPassId` and sends it to the cloud for validation. The cloud checks: (1) Does `guestPasses/{passId}` exist? (2) Is `isRevoked: false`? (3) Is `expiresAt` in the future? If all pass, the unlock command is sent via MQTT. Access log is written with method `"QR"` and `visitorName`.

**Revocation:** The resident can tap "Revoke" on any active pass in the Guest Management screen. This immediately sets `isRevoked: true` in Firestore. Since the M5Stack validates against live Firestore data, a revoked pass is blocked instantly on the next scan attempt.

```
Resident creates pass → guestPasses/ document + QR generated
Guest enters one-time code → QR displayed on their screen
Guest holds QR to door camera
    → M5Stack decodes guestPassId
    → Cloud checks guestPasses/{passId} (expiry, revocation)
    → Servo unlock (if valid) or door stays locked + "Denied" log (if invalid)
    → access_logs/ entry written
```

---

### 6.4 Admin Force Unlock

An admin can trigger an emergency unlock from the Lock Management screen regardless of whether any resident is present or the app is active.

Tapping "Force Unlock" on a lock row calls a Firestore write to `locks/{lockId}/pendingCommands` with `{ command: "unlock", requestedBy: adminUid, type: "admin_override", status: "pending", logId }`. The M5Stack listener picks this up, skips resident-credential validation (admin override bypasses the device/UUID check), and immediately drives the servo. The access log entry is updated to `status: "executed"` and `method: "admin_override"` by the M5Stack.

Admins can also issue a `"lockdown"` command that disables all BLE and QR entry until lifted. The M5Stack stores a `isLockedDown` flag in memory and checks it before processing any entry request.

---

### 6.5 Device Registration & Revocation

**Registration:** A new resident navigates to Profile → Device Settings. The app reads the phone's current BLE Service UUID (generated by `flutter_blue_plus`). This UUID is saved to `devices/{deviceId}` in Firestore with fields: `uuid`, `ownedBy` (resident UID), `registeredAt`, `isRevoked: false`, `platform` (iOS/Android). The M5Stack refreshes its local UUID cache from Firestore on a timed interval and on MQTT push.

**Revocation:** An admin navigates to Manage Users, finds the resident, and taps "Revoke Access." This sets `isRevoked: true` on all `devices/` documents where `ownedBy == residentUid`. It also disables the Firebase Auth account. The M5Stack's next cache refresh will exclude the revoked UUID. For immediate enforcement, the cloud also publishes a `revoke:{uuid}` MQTT message which the M5Stack processes to instantly purge the UUID from its in-memory cache.

---

### 6.6 Auto-Relock

Every unlock event — regardless of trigger type — starts a 5-second relock timer in `servo_controller.py`. After 5 seconds, `auto_relock()` raises the servo arm, pulling the cloned ID card away from the door reader. The door re-locks. This timer is not cancellable from the app. If a second unlock request arrives while the relock timer is running, the timer resets to 5 seconds from the new event.

---

## 7. Security Model

Ntry uses a **Zero Local Trust** architecture. The edge device (M5Stack) is treated as untrusted hardware. It never makes an access decision unilaterally.

**Authentication:** Firebase Auth handles all user authentication. Email/password and Google Sign-In both issue a Firebase JWT. This JWT is included in all app-to-cloud requests and validated server-side via Firebase Security Rules. JWTs expire after 1 hour and are automatically refreshed by the Firebase SDK.

**BLE anti-spoofing:** Modern phones randomize their BLE MAC address to prevent tracking, which is why Ntry uses a custom **Service UUID** instead of MAC address. However, UUIDs can theoretically be observed and replicated by an attacker with the right tools. The Zero Local Trust model mitigates this — even if someone replays a UUID, the cloud validates the associated JWT and account status before issuing an unlock command. A replayed UUID without a valid, non-expired JWT gets rejected.

**QR code security:** QR codes encode only a `guestPassId` (not a full JWT), so the QR image alone is useless without a matching, non-revoked, non-expired Firestore document. The cloud is the only authority that can greenlight entry.

**MQTT security:** All M5Stack ↔ Cloud IoT Core communication runs over MQTT with TLS. The M5Stack authenticates to Cloud IoT Core using an RSA private key stored on-device. Commands arriving over any other channel are ignored.

**Firebase Security Rules:** Firestore rules enforce role-based access. Residents can only read/write their own `users/` and `devices/` documents and their own `guestPasses/`. Admins have broader read access and can write to `locks/`. `access_logs/` is writable by authenticated users (for enqueue-time logs) and by the M5Stack service account (for execution-time logs); readable by admins (all logs) and residents (own lock's logs only, scoped by `lock_id`).

**Biometric gate:** The Flutter app requires biometric (FaceID/TouchID) or PIN authentication before displaying the Unlock button or the Guest Pass screens. This prevents someone who steals an unlocked phone from operating the door or generating guest passes.

---

## 8. Cloud Infrastructure (GCP + Firebase)

All cloud infrastructure runs under a single GCP project. Here is what is provisioned and what it does.

**Firebase Authentication** manages all user accounts. Residents self-register via the app using email/password or Google Sign-In. Admin accounts are created manually in the Firebase Console and tagged with a custom claim (`"role": "admin"`) using the Firebase Admin SDK. The app reads this claim after login to determine which dashboard to render.

**Cloud Firestore** is the primary database for persistent app data. The mobile app uses real-time snapshot listeners so app state stays in sync. Security rules are defined in `firestore.rules` in the repo root. Collections are described in full in §11.

**Firebase Realtime Database (RTDB)** is used for the unlock command path (`locks/{lockId}/pendingCommand`). RTDB's persistent WebSocket connection gives the M5Stack sub-200ms command delivery via `setStreamCallback` on a dedicated FreeRTOS task — far faster than Firestore polling. RTDB is used only for this one node; all other data lives in Firestore.

**Cloud Functions (optional / future):** Complex validation logic (e.g., checking JWT expiry, writing access logs atomically) can be moved to Firebase Cloud Functions if needed.

---

## 9. Hardware — M5Stack CoreS3 (ESP32S3)

### 9.1 Device Overview

The M5Stack CoreS3 is an ESP32S3-based development kit with a built-in 2-inch touchscreen, Wi-Fi, Bluetooth, and a USB-C port. It runs **MicroPython** firmware. This is the physical door controller — it lives mounted at the door, connected to power via USB-C, with the servo motor and camera module wired to it.

Key specs relevant to Ntry:
- **MCU:** ESP32S3 (dual-core, 240 MHz)
- **BT:** Bluetooth 5.0 LE (used for UUID scanning)
- **Wi-Fi:** 802.11 b/g/n (used for MQTT to Cloud IoT Core and Firestore)
- **Display:** 2" IPS touchscreen (320×240) — used for local status UI and emergency override
- **GPIO:** Multiple available pins (see §9.2)
- **USB-C:** Powers the device and connects the camera module

---

### 9.2 Pin Mapping & Wiring

The following pin assignments are defined in `firmware/config.py` and should not be changed without updating `config.py` first.

```python
# firmware/config.py — GPIO constants

SERVO_PIN     = 2    # PWM signal to servo motor signal wire
SERVO_FREQ    = 50   # Hz (standard servo PWM frequency)
SERVO_DUTY_UNLOCK = 77   # Duty cycle to lower card (~0.6ms pulse → ~0°)
SERVO_DUTY_LOCK   = 40   # Duty cycle to raise card (~2.0ms pulse → ~120°)

CAMERA_POWER_PIN  = 4    # HIGH to power on camera module
STATUS_LED_PIN    = 19   # Optional onboard LED for visual feedback
```

**Wiring table:**

| M5Stack Pin | Connected To | Wire Color (convention) |
|---|---|---|
| G2 (GPIO 2) | Servo signal wire | Yellow / Orange |
| 5V | Servo power (VCC) | Red |
| GND | Servo ground | Brown / Black |
| USB-C | Camera module (power + data) | Native USB-C cable |
| G19 (GPIO 19) | Status LED (optional) | — |

**Servo wiring detail:** Standard hobby servos have three wires — power (red, 5V), ground (brown/black), and signal (yellow/orange, PWM). The M5Stack's G2 outputs the PWM signal. Power the servo from the 5V rail, not 3.3V — insufficient voltage will cause the servo to stutter or fail under load. If the servo draws too much current and resets the M5Stack, power the servo from an external 5V source sharing a common ground with the M5Stack.

**Camera module:** The USB-C camera module connects directly to the M5Stack CoreS3's USB-C port. It presents as a UVC (USB Video Class) device. MicroPython's `camera` module or a compatible UVC driver handles frame capture. Ensure the camera is powered on via `CAMERA_POWER_PIN` before attempting capture.

---

### 9.3 Servo Motor & Mechanical Retrofit

The core of Ntry's non-invasive approach is a 3D-printed arm that mounts above the existing door card reader. The arm holds a cloned MIFARE Classic 1K ID card (cloned via Flipper Zero). The servo motor raises and lowers this arm, pressing the card against the reader to unlock.

**Card cloning:** Use the Flipper Zero to read the original dorm access card (`RFID → Read Card`). Save the card data, then write it to a blank MIFARE Classic 1K card (`RFID → Write Card`). Verify the clone independently opens the door reader before integrating it into the mount. Keep the original card as a backup. Never clone a card onto the only physical backup.

**3D-printed mount:** The mount consists of:
- A base plate that attaches to the wall/door frame (non-damaging adhesive or screw mount depending on facility rules)
- A pivot arm that holds the card
- A servo horn connector that translates servo rotation to arm movement

The mount went through at least one iteration (v1 delivered in Sprint 5). If reprinting, validate fitment on the actual door before the demo.

**Servo calibration:** The two duty cycle values in `config.py` (`SERVO_DUTY_UNLOCK` and `SERVO_DUTY_LOCK`) control the arm position. These values may need adjustment depending on the exact servo model and print dimensions. To calibrate: power the servo, set duty to `SERVO_DUTY_UNLOCK`, and confirm the card rests firmly against the reader. Set duty to `SERVO_DUTY_LOCK` and confirm the card clears the reader completely. Adjust in small increments if not.

---

### 9.4 Camera Module & QR Scanning

The USB-C camera module is used solely for QR code scanning. It does not perform facial recognition or any video streaming. Frame capture happens in `qr_scanner.py`.

The scan loop works as follows: the camera captures a frame at a low resolution (320×240 is sufficient for QR decoding and reduces processing load). The frame is decoded using a MicroPython-compatible QR library. If a valid QR payload is detected, the `guestPassId` string is extracted and passed to `cloud_validator.py` for Firestore lookup. If no QR is detected in the frame, the loop continues immediately.

**Gotcha:** QR scanning is computationally heavy for a microcontroller. If the scan loop blocks the MQTT listener or BLE scanner, consider running the QR scanner on a lower-priority timer or in a cooperative multitasking pattern with `uasyncio`. See §17 for known issues here.

---

### 9.5 BLE Scanning on the ESP32S3

`ble_scanner.py` uses the ESP32S3's onboard Bluetooth radio to continuously scan for BLE advertisement packets. The scanner is looking for packets that include a specific Service UUID in the advertisement data.

The BLE scan is configured as a passive scan (no connection established — purely observing advertisements) with a scan interval and window tuned for low latency detection. When a UUID matching an entry in the local `authorized_uuids` cache is detected with RSSI above the threshold, the scanner fires a callback to `cloud_validator.py`.

**RSSI threshold:** RSSI of -65 dBm corresponds roughly to 2 feet in an indoor environment. This value is defined in `config.py` as `BLE_RSSI_THRESHOLD = -65`. It may need tuning in the actual dorm hallway environment — concrete walls and metal door frames affect signal propagation. If false positives (unlocking from too far away) occur, increase the threshold toward -55. If the door fails to detect the phone reliably, decrease toward -75.

**UUID caching:** The M5Stack loads authorized UUIDs from Firestore into memory at startup via an HTTP request. It refreshes this cache every 30 seconds and also immediately on receiving a `revoke:{uuid}` MQTT command. The cache is a Python `set` for O(1) lookup.

---

### 9.6 MicroPython Firmware Notes

The M5Stack runs MicroPython. A few things to know if you're working on the firmware:

Flashing firmware: Use `esptool.py` to flash the MicroPython binary. Download the correct build for ESP32S3 from the MicroPython downloads page. After flashing, use `mpremote` or `Thonny` to transfer `.py` files to the device filesystem.

File transfer workflow: `mpremote connect /dev/ttyUSB0 cp firmware/*.py :` will copy all firmware files to the device. After copying, reset the device to run `main.py`.

OTA updates: The `ota_updater.py` module handles over-the-air firmware updates via Google Cloud IoT Core device management. When a new firmware version is available, the cloud publishes a download URL to the device command topic. The M5Stack downloads the new `.py` files, writes them to flash, and restarts. This means you can push firmware patches without physical access to the device — critical once it's mounted on an actual dorm door.

`uasyncio`: The firmware uses MicroPython's `uasyncio` for cooperative multitasking. The BLE scanner, MQTT client, QR scanner, and Firestore listener all run as async coroutines. Do not add blocking calls (e.g., `time.sleep()`) inside these coroutines — use `await uasyncio.sleep_ms()` instead.

---

## 10. Mobile App — Flutter

### 10.1 Screen Map & Navigation

The app has 19 screens split across three user personas. Role-based routing is handled by GoRouter — immediately after Firebase Auth resolves, the router reads the user's `role` from Firestore and redirects to the appropriate entry screen.

```
Screen 1:  Splash Screen
               ↓ (auto-transition, waits for Firebase auth)
Screen 2:  Login Screen
           ├── [Resident / Admin login via email or Google]
           └── [Guest code entry link] → Screen 3: Guest Code Entry
                                             ↓
                                     Screen 4: Guest QR Display

           PENDING APPROVAL FLOW (both roles)
           Screen 5:  Pending Approval Screen
               └── (real-time listener — auto-redirects to home when approved)

           RESIDENT FLOW
           Screen 6:  Resident Home (Unlock button + BLE status)
               ├── Screen 7:  Activity (access log for this resident's lock, via shared AccessLogView widget)
               ├── Screen 8:  Guest Management (list + revoke)
               ├── Screen 9:  Device Settings (register device, BLE UUID)
               └── Screen 10: Profile

           ADMIN FLOW
           Screen 11: Admin Home Dashboard (live pending-approval badge)
               ├── Screen 12: Manage Users (Pending tab + All Users tab)
               ├── Screen 13: Access Logs (full building log)
               ├── Screen 14: Lock Management (Force Unlock / Lockdown)
               │       ├── Screen 15: Add Lock (name, room, location dropdown, device ID)
               │       └── Screen 16: Lock Detail (edit lock fields, manage user access)
               └── Screen 17: Location Management (list of org locations)
                       ├── Screen 18: Add Location (name, guest pass settings)
                       └── Screen 19: Location Detail (edit name, guest pass settings)
```

**New user onboarding:** First-time users (no Firestore profile yet) are redirected to the Onboarding screen after login to complete their profile. On submit, `approvalStatus: "pending"` is written for all users. The router then routes them to `/pending`.

**Approval flow:** All new users (resident or admin) land on `/pending` after onboarding. An approved admin in their organization reviews requests in Manage Users → Pending tab and approves or denies. When approved, a Firestore real-time listener on the pending screen fires `refreshProfile()`, which causes the router to redirect automatically to the correct home screen. The first admin of a new organization must be manually set to `approvalStatus: "approved"` in the Firebase Console by a developer.

**Navigation implementation:** GoRouter with role-based redirect logic in `lib/routing/app_router.dart`. The router listens to `AuthService` (a `ChangeNotifier`) and re-evaluates redirects on any auth state change. Resident and Admin flows use separate route prefixes (`/home/...` vs `/admin-home/...`) to keep back-navigation scoped correctly.

**Biometric gate:** Screens 5 (Unlock button) and the Create Guest Pass action within Screen 7 are individually gated with `local_auth` before the sensitive action renders. The gate is widget-level, not router-level.

---

### 10.2 BLE Advertising (Phone Side)

> **Status: Planned — not yet implemented.**

The BLE advertising service will live in `lib/services/ble_service.dart` and use `flutter_blue_plus` to broadcast a custom BLE service advertisement containing the resident's registered Service UUID.

The service should start automatically when the resident logs in and be registered as a background service so it continues even when the app is not in the foreground. On iOS, background BLE advertising has limitations — the advertisement is not visible to scanning devices when the app is truly backgrounded on iOS 13+, but CoreBluetooth will resume advertising briefly when the device approaches a known BLE scanner. Android is generally more permissive about background BLE advertising.

The Service UUID is generated once during device registration (a standard UUID v4) and stored in `devices/{deviceId}` in Firestore. It never changes unless the resident re-registers a new device.

---

### 10.3 Biometric Lock

> **Status: Planned — not yet implemented.**

`local_auth` Flutter package will handle biometric/PIN authentication. Call `authenticateUser()` before any sensitive action. The function returns a `Future<bool>` — `true` if auth succeeds, `false` if the user cancels or fails.

On first launch (or after a fresh login), the app should prompt the user to enable biometric for the device if not already set up. If the device has no biometric hardware, PIN fallback is used.

---

### 10.4 UI Design Reference

All wireframes and interactive prototypes live in Figma:

**Figma Public Demo:** [https://www.figma.com/make/oOcOqq6lZtPpMk8BIJM4Br/Build-Mobile-App-Interface](https://www.figma.com/make/oOcOqq6lZtPpMk8BIJM4Br/Build-Mobile-App-Interface)

The Figma file contains both UI (visual design) and UX (clickable transitions between screens). Use it as the design authority when building new screens or making visual changes. Do not deviate from the design without team discussion.

**Implemented design system (in `lib/theme/`):**
- **Background:** `#0A0A0A` (near-black)
- **Surface:** `#141414` / Elevated: `#1E1E1E`
- **Accent:** `#00D4AA` (teal — primary interactive color)
- **Error:** `#FF6B6B` (red)
- **Text:** `#F5F5F5` (primary) / `#6B6B6B` (secondary/subtle)
- **Font:** Inter (via `google_fonts`)
- **Theme:** Dark mode (Material 3). Light mode is a future TODO.
- All loading states use a centered circular progress indicator.

---

### 10.5 Data Layer & State Management

All Firestore access is routed through **helper classes** (one per collection) and **provider singletons**. Screens must not call `FirebaseFirestore.instance` directly.

#### Database Helpers (`lib/database/`)

Each helper is an instantiable class with a `final _firestore = FirebaseFirestore.instance` field and typed instance methods. Instantiate as needed — they hold no mutable state.

| Helper | Collection | Key Methods |
|---|---|---|
| `UserHelper` | `users/` | `getUser`, `streamUser`, `setUserProfile`, `updateUser`, `streamUsersByOrg`, `getUsersByOrg`, `streamUsersByLock`, `updateApproval`, `assignLock` |
| `LockHelper` | `locks/` | `stream`, `getByOrg`, `streamByOrg`, `create`, `update`, `unlock`, `relock` |
| `LocationHelper` | `locations/` | `streamByOrg`, `getByOrg`, `create`, `update` |
| `GuestHelper` | `locks/{id}/guests` | `streamGuests`, `createGuest`, `deleteGuest` |

**Rule:** If a screen needs a one-time read, call `getXxx()`. If it needs to react to live changes, call `streamXxx()` and wrap in a `StreamBuilder`.

#### Providers (`lib/providers/`)

Providers are global `ChangeNotifier` singletons initialized in `main.dart` (after `authServiceInstance`). They stream live Firestore data and expose fields synchronously to the widget tree.

| Singleton | Listens to | Exposes |
|---|---|---|
| `userProviderInstance` | `authServiceInstance` → `users/{uid}` | `firstName`, `lastName`, `organization`, `lockId`, `role`, `approvalStatus`, `displayName` |
| `lockProviderInstance` | `userProviderInstance.lockId` → `locks/{lockId}` | `room`, `name`, `status`, `unlocked`, `isLockedDown` |

**Initialization order** (must match `main.dart`):
```dart
authServiceInstance = AuthService();      // 1. Auth (no deps)
userProviderInstance = UserProvider();    // 2. User (depends on auth)
lockProviderInstance = LockProvider();    // 3. Lock (depends on user)
themeNotifierInstance = ThemeNotifier();  // 4. Theme (no deps)
```

**Usage in widgets:**
```dart
// Single provider
ListenableBuilder(
  listenable: userProviderInstance,
  builder: (context, _) => Text(userProviderInstance.displayName ?? ''),
)

// Multiple providers
ListenableBuilder(
  listenable: Listenable.merge([userProviderInstance, lockProviderInstance]),
  builder: (context, _) { ... },
)
```

**AuthService cached fields:** `authServiceInstance` also caches `firstName`, `lastName`, and `organization` (populated in `_checkProfile()` from Firestore). Use these for synchronous reads in admin screens where the full `UserProvider` stream is not needed.

---

## 11. Database Schema — Cloud Firestore

Firestore is a document-based NoSQL database. Documents live inside collections. Here is the full schema.

---

**`users/{uid}`**

Stores profile data for every registered user. `uid` matches the Firebase Auth UID.

```
{
  first_name: string,
  last_name: string,
  email: string,
  role: "resident" | "admin",
  organization: string,            // "Individual" (personal device) or org name e.g. "CBU"
  lock_id: string,                 // ID of the locks/ document assigned to this resident (set on approval)
  createdAt: timestamp,
  hasCompletedOnboarding: boolean, // true once onboarding form is submitted
  ownDevice: boolean,              // true if resident selected "I have my own personal Ntry device"
  approvalStatus: "pending" | "approved" | "denied",
                                   // written as "pending" on onboarding submit for all users;
                                   // set to "approved"/"denied" by an admin in Manage Users
  isActive: boolean                // false = account suspended (set by admin post-approval)
}
```

> **Note:** `isActive` is not written during onboarding — it defaults to `true` conceptually and is only explicitly set to `false` by an admin action. If your Firestore rules or queries depend on this field, handle the `undefined` case.

> **Composite index required:** Queries on `(organization, approvalStatus)` require a composite Firestore index. Create it in the Firebase Console → Firestore → Indexes, or click the link in the Flutter debug console error when the query first runs. Collection: `users`, fields: `organization ASC, approvalStatus ASC`.

---

**`devices/{deviceId}`**

One document per registered device. A resident may have multiple devices (e.g., phone + tablet).

```
{
  uuid: string,             // BLE Service UUID advertised by this device
  ownedBy: string,          // uid of the resident
  platform: "ios" | "android",
  registeredAt: timestamp,
  isRevoked: boolean        // true = blocked immediately on next cache refresh
}
```

---

**`guestPasses/{passId}`**

One document per guest pass. The QR code at the door encodes only `passId`.

```
{
  passId: string,           // matches document ID
  token: string,            // signed JWT (server-validated, not decoded on device)
  createdBy: string,        // uid of the resident who created the pass
  visitorName: string,
  lockId: string,           // which lock this pass is valid for
  createdAt: timestamp,
  expiresAt: timestamp,
  isRevoked: boolean,
  usageCount: number        // optional: number of times used
}
```

---

**`access_logs/{logId}`**

Append-only. Written by authenticated mobile clients (enqueue-time) and the M5Stack service account (execution-time) on every access event.

```
{
  lock_id: string,
  user_id: string,
  visitor_name: string | null,                    // null for resident entries; guest name for QR/BLE guests
  method: "manual" | "BLE" | "QR" | "admin_override",
  timestamp: timestamp,                           // FieldValue.serverTimestamp()
  status: "pending" | "executed" | "failed",      // app writes "pending"; M5Stack updates to "executed"
  denied_reason: string | null,                   // "expired" | "revoked" | "not_found" | "lockdown" | null
  details: string | null                          // optional freeform context
}
```

**UI display mapping (status → label):** `"executed"` → "Granted", `"failed"` → "Denied", `"pending"` → "Pending". This mapping lives in `AccessLogView` — Firestore and firmware always use the raw values.

---

**`locations/{locationId}`**

One document per named location within an organization. Locations group one or more locks under shared access policies. Created via Location Management → Add Location, or automatically when an admin adds a lock with a new location name.

```
{
  name: string,                      // e.g., "Colony Living Area", "Smith Hall"
  organization: string,              // org this location belongs to
  guestPassEnabled: boolean,         // whether residents can issue guest passes for locks at this location
  guestPassMaxDurationHours: number, // maximum guest pass validity in hours
  createdAt: timestamp,
  latitude: number | null,           // GPS latitude for map navigation (optional; set in admin Location Detail)
  longitude: number | null           // GPS longitude for map navigation (optional; set in admin Location Detail)
}
```

> **Auto-relock delay** is hardware-managed (configured in `src/main.cpp` on the M5Stack; currently 2 seconds). It is not stored in Firestore and is not configurable from the admin UI.

> **Composite index required:** Queries on `(organization, name)` may require a composite Firestore index if sorting is added. Create in Firebase Console → Firestore → Indexes.

---

**`locks/{lockId}`**

One document per physical lock/door.

```
{
  name: string,             // e.g., "Room 204 — North Hall"
  room: string,             // short room label displayed in the resident home header (e.g. "Room 204")
  location: string,         // display name of the building/area (denormalized from locations/ for easy display)
  locationId: string,       // reference to locations/{locationId} — use this to look up access policies
  organization: string,     // org this lock belongs to (used for admin-scoped queries)
  deviceId: string,         // M5Stack device ID registered in Cloud IoT Core
  isLockedDown: boolean,    // if true, all entry methods blocked
  unlocked: boolean,        // live unlock state; written true on unlock, false after 5-second relock
  timestamp: timestamp,     // server timestamp of the last unlock/relock event (FieldValue.serverTimestamp())
  lastEvent: timestamp,
  status: "locked" | "unlocked"
}
```

**`locks/{lockId}/pendingCommand`** (RTDB node — primary command transport)

Used for app → M5Stack communication. M5Stack listens via RTDB `setStreamCallback` on a dedicated FreeRTOS task. Node is overwritten (`.set()`) on each command; M5Stack deletes it after processing.

```
{
  command: "unlock",
  requestedBy: string,      // uid
  status: "pending",
  logId: string             // reference to access_logs/{logId}; M5Stack patches that doc on execution
}
```

Swappable to Firestore via `USE_RTDB 0` (firmware) / `_useRtdb = false` (mobile). Firestore fallback path below.

**`locks/{lockId}/pendingCommands/{commandId}`** (Firestore subcollection — fallback only)

```
{
  command: "unlock" | "lockdown" | "lift_lockdown",
  requestedBy: string,      // uid
  type: "resident" | "admin_override",
  requestedAt: timestamp,
  status: "pending" | "executed",
  logId: string
}
```

---

**`locks/{lockId}/guests/{guestId}`** (subcollection)

One document per active guest pass associated with a specific lock. Written by `GuestHelper.createGuest()`, read via `GuestHelper.streamGuests()`. Fields are flat and lowercase.

```
{
  name: string,           // visitor's name as entered by the resident
  passkey: string,        // one-time code the visitor enters to view the QR
  initTime: string,       // ISO 8601 datetime string; pass expires initTime + 2 hours
  isRevoked: boolean      // set to true by resident to revoke access; M5Stack checks this during QR validation
}
```

> **Field naming:** All three fields are flat and lowercase — `name`, `passkey`, `initTime`. Do not use nested objects or capitalized keys.

---

## 12. Environment Variables & Secrets

**Never commit secrets to the repository.** The following values must be set up locally.

**Flutter app** — Firebase config is handled via `lib/firebase_options.dart` (auto-generated by `flutterfire configure`). Do not commit `google-services.json` or `GoogleService-Info.plist` to the repo.

**M5Stack firmware** — create `src/secrets.h` in `ntry_edge/` (gitignored):

```cpp
// src/secrets.h
#define WIFI_SSID "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"
#define CLOUD_IOT_PROJECT_ID "your-gcp-project-id"
#define CLOUD_IOT_REGION "us-central1"
#define CLOUD_IOT_REGISTRY "ntry-device-registry"
#define CLOUD_IOT_DEVICE_ID "m5stack-door-01"
// RSA private key for MQTT — paste PEM content as a multiline string literal
#define MQTT_PRIVATE_KEY "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n"
```

The RSA private key is generated during device provisioning in Cloud IoT Core (see §13.2). Store the private key file securely — it is the device's identity credential.

**Google Cloud service account** — For server-side operations (Cloud Functions, Admin SDK), download the service account JSON from the GCP Console. Never commit it. Reference it via the `GOOGLE_APPLICATION_CREDENTIALS` environment variable in local dev.

---

## 13. Setup & Installation

### 13.1 Prerequisites

Before starting, make sure you have the following installed:

- **Flutter SDK** (stable channel, 3.x+): https://flutter.dev/docs/get-started/install
- **Dart SDK** (bundled with Flutter)
- **Android Studio** or **Xcode** (for device simulators and iOS signing)
- **PlatformIO IDE** (VS Code extension or CLI): https://platformio.org/install — used for M5Stack firmware (Arduino C++ via PlatformIO, not MicroPython)
- **Firebase CLI**: `npm install -g firebase-tools`
- **FlutterFire CLI**: `dart pub global activate flutterfire_cli`
- **Google Cloud SDK (gcloud)**: https://cloud.google.com/sdk/docs/install
- A physical **M5Stack CoreS3** device
- A physical iOS or Android device (BLE background advertising does not work on simulators)

---

### 13.2 Firebase / GCP Setup

**Step 1 — Create a Firebase project:**
Go to https://console.firebase.google.com → Add project → name it (e.g., `ntry-prod`). Enable Google Analytics if desired.

**Step 2 — Enable Firebase Authentication:**
In the Firebase Console → Authentication → Sign-in method → Enable Email/Password and Google.

**Step 3 — Enable Cloud Firestore:**
Firebase Console → Firestore Database → Create database → Start in production mode → choose a region. After creation, go to Rules and deploy the rules from `firestore.rules` in the repo:
```
firebase deploy --only firestore:rules
```

**Step 4 — Configure the Flutter app:**
```bash
flutterfire configure
```
This generates `lib/firebase_options.dart` automatically for all platforms.

**Step 5 — Create an Admin user:**
After your first user signs up, use the Firebase Admin SDK (or a one-time Node script) to set the custom claim:
```javascript
admin.auth().setCustomUserClaims(uid, { role: 'admin' });
```
The user must sign out and sign back in for the new claim to be reflected in their token.

**Step 6 — Enable Google Cloud IoT Core:**
In the GCP Console → API Library → enable "Cloud IoT API". Then:
```bash
gcloud iot registries create ntry-device-registry \
  --region=us-central1 \
  --event-notification-config=topic=projects/YOUR_PROJECT_ID/topics/ntry-telemetry
```

**Step 7 — Register the M5Stack as a device:**
Generate an RSA key pair for the M5Stack:
```bash
openssl genpkey -algorithm RSA -out m5stack_private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -in m5stack_private.pem -pubout -out m5stack_public.pem
```
Register the device:
```bash
gcloud iot devices create m5stack-door-01 \
  --region=us-central1 \
  --registry=ntry-device-registry \
  --public-key=path=m5stack_public.pem,type=rsa-x509-pem
```
Copy the content of `m5stack_private.pem` into `firmware/secrets.py` as `MQTT_PRIVATE_KEY`.

---

### 13.3 Flutter App Setup

```bash
# Clone the mobile repo
git clone https://github.com/Ntry-SAS/ntry_mobile.git
cd ntry_mobile

# Install dependencies
flutter pub get

# Run on a connected device (not simulator — BLE required)
flutter run
```

For iOS, you'll also need to set up code signing in Xcode with your Apple Developer account and enable the following capabilities: Bluetooth Background Modes, Face ID / Touch ID.

For Android, ensure the following permissions are in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.CAMERA" />
```

---

### 13.4 M5Stack Firmware Setup

> **Language note:** The M5Stack firmware is written in **Arduino C++** using **PlatformIO**, not MicroPython. The firmware lives in the `ntry_edge/` repo (`src/main.cpp`). References to MicroPython, `esptool.py`, or `mpremote` in older docs are outdated.

**Step 1 — Install PlatformIO:**
Install the PlatformIO IDE extension for VS Code, or install the CLI:
```bash
pip install platformio
```

**Step 2 — Open the firmware project:**
```bash
cd ntry_edge
# Open in VS Code — PlatformIO will auto-detect platformio.ini
code .
```

**Step 3 — Configure credentials:**
Copy `src/secrets.h.example` to `src/secrets.h` and fill in your Wi-Fi credentials and GCP / IoT Core details:
```cpp
// src/secrets.h
#define WIFI_SSID "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"
#define CLOUD_IOT_PROJECT_ID "your-gcp-project-id"
#define CLOUD_IOT_REGION "us-central1"
#define CLOUD_IOT_REGISTRY "ntry-device-registry"
#define CLOUD_IOT_DEVICE_ID "m5stack-door-01"
```
The RSA private key for MQTT authentication is also stored here. Never commit `secrets.h` — it is gitignored.

**Step 4 — Build and upload:**
```bash
pio run --target upload
# Or use the PlatformIO VS Code sidebar: Build → Upload
```
PlatformIO automatically detects the M5Stack CoreS3 (ESP32S3) board config from `platformio.ini`.

**Step 5 — Monitor serial output:**
```bash
pio device monitor --baud 115200
```
You should see the M5Stack connecting to Wi-Fi, establishing a Firestore connection, and displaying lock status on the touchscreen.

**Step 6 — Calibrate servo:**
The servo is connected to **GPIO 38** (not GPIO 2 as listed in older pin maps). Adjust `SERVO_PIN`, `SERVO_ANGLE_LOCK`, and `SERVO_ANGLE_UNLOCK` constants in `src/main.cpp` if physical calibration is needed, then re-upload.

---

## 14. Git Workflow & PR Process

### Branch Structure

```
main        ← Default branch. Production-ready, demo-stable code only.
             Only updated via approved PR from staging.
  └── staging  ← Integration branch. All features land here first.
                 Always branch from staging for new work.
       └── feature-{jira#}-{description}  ← Your working branch
```

**The rule is simple: no one merges their own work. Everyone opens a PR and waits for review.**

---

### Starting a New Feature

```bash
git checkout staging
git pull origin staging
git checkout -b feature-42-guest-pass-ui
```

Branch naming convention: `feature-{jira-ticket-number}-{short-description}` using hyphens throughout. Match the Jira ticket number exactly.

Examples:
- `feature-47-merge_branches`
- `feature-41-authentication_flow`
- `feature-55-ble-advertising`

Bug fixes follow the same pattern: `fix-{jira#}-{short-description}`

---

### Opening a PR

1. Push your branch: `git push origin feature-42-guest-pass-ui`
2. Open a PR on GitHub from your feature branch → `staging`
3. PR title format: `[NTR-42] Short imperative description`
4. Require at least one reviewer approval before merging
5. **Do not merge your own PR.** Assign a reviewer and wait.
6. Delete the feature branch after it is merged.

**PRs go to `staging`, not `main`.** The only PRs that go to `main` are from `staging`, and those are a team decision made before a demo or milestone.

---

### Commit Message Format

```
[NTR-XX] Short imperative description (50 chars max)

Longer explanation if needed. What changed and why.
What was tricky. Anything a future dev should know.
```

---

## 15. Jira Workflow

Every ticket moves through four columns on the Jira board:

```
TO DO  →  IN PROGRESS  →  FEATURE DONE (CODE IN BRANCH)  →  DONE (GIT MERGED/PR'D)
```

| Column | Meaning |
|---|---|
| **TO DO** | Ticket exists, nobody has started it yet |
| **IN PROGRESS** | You have created your branch and are actively working on it |
| **FEATURE DONE (CODE IN BRANCH)** | Code is complete and pushed to your feature branch. PR is open. |
| **DONE (GIT MERGED/PR'D)** | PR has been reviewed, approved, and merged into `staging` |

**Move your ticket yourself** as you progress. Do not leave tickets in IN PROGRESS after your PR is open — move it to FEATURE DONE so reviewers know it is ready.

---

## 16. Testing Strategy & Acceptance Criteria

Each core flow has a pass/fail acceptance criterion. Before any PR to `staging` is merged, the author should verify their feature against the relevant criterion below.

**BLE Proximity Unlock:** Stand within 2 feet of the M5Stack with a registered phone. The door must unlock within 3 seconds. Then stand 10+ feet away — the door must not unlock. Verify the access log shows a "BLE / granted" entry.

**Manual App Unlock:** Tap Unlock in the app (after biometric). The servo should actuate within 3 seconds. Verify the log entry. Then revoke the device in the Admin panel and attempt again — access must be denied.

**Guest QR Entry:** Generate a guest pass. Present the QR to the camera. Door must unlock. Then revoke the pass and present again — door must stay locked and log a "QR / denied / revoked" entry. Generate a pass, wait for expiry, and present — same denied outcome.

**Admin Force Unlock:** From the Admin dashboard, tap Force Unlock. The servo must actuate regardless of whether the resident app is running. Verify the log shows "admin_override / granted."

**Device Revocation:** Register a device. Confirm it unlocks via BLE. Revoke it in the Admin panel. Within 30 seconds, attempt BLE entry — access must be denied. Attempt manual unlock — denied.

**Biometric Gate:** Attempt to access the Unlock screen or Create Guest Pass screen without completing biometric. Must be blocked.

**Auto-Relock:** Trigger any unlock. Count 2 seconds (current firmware value in `main.cpp`). Confirm the servo retracts. The door reader should no longer be activated.

---

## 17. Known Bugs & Gotchas

These are real issues encountered during development. Know them before you start so you don't spend hours rediscovering them.

**iOS BLE background advertising limitations.** iOS 13+ does not allow BLE advertising with a full service UUID when the app is truly backgrounded (screen off, app suspended). Instead, iOS uses a system-managed overflow area that other iOS devices can detect but generic BLE scanners may not. During testing, keep the screen on or the app in the foreground for reliable BLE detection. This is an Apple OS limitation.

**RSSI variance in dorm hallways.** Concrete and drywall significantly affect BLE signal strength. The -65 dBm threshold was tuned in a specific environment. In a different hallway or with a different phone model, this threshold may be too aggressive (causing early unlocks) or too conservative (causing missed detections). Always retune in the actual deployment environment.

**M5Stack MQTT reconnection.** If the M5Stack loses Wi-Fi connectivity, the MQTT client disconnects. If reconnection fails repeatedly, the device may fall into a blocking retry loop that prevents the BLE scanner and QR scanner from running. Implement a reconnection timeout and fall back gracefully — the device should still log locally even when cloud-disconnected (though it must not unlock without cloud validation).

**QR scanner blocking BLE scanner.** The M5Stack uses Arduino cooperative task scheduling (FreeRTOS tasks or loop-based polling). If QR frame capture takes too long in the main loop, BLE advertisement packets may be missed. Consider running BLE scanning and QR scanning on separate FreeRTOS tasks, or rate-limiting QR scan to 5 FPS.

**RTDB stream reconnect latency.** The M5Stack RTDB stream (`setStreamCallback`) can silently reconnect after idle timeout. The first command after a long idle period may take 2–3s while the stream reestablishes. Subsequent commands within the same session are ~100–200ms. Watch serial for `[RTDB] stream timeout — reconnecting`.

**Admin user claim not reflected immediately.** After setting a custom `role: 'admin'` claim via the Admin SDK, the user's ID token is not updated until they sign out and sign back in. If an Admin logs in and sees the Resident dashboard, they need to sign out and sign in again.

**Servo jitter on startup.** When the M5Stack first boots and initializes the PWM output, the servo may briefly jitter before settling to the locked position. This is a PWM initialization artifact. Add a 500ms delay after PWM init before commanding the servo to `SERVO_DUTY_LOCK` position.

**3D-printed mount fitment.** The v1 mount may require iteration depending on the exact door reader model and mounting surface. Always test fitment before a demo. Keep spare mounting adhesive and the Flipper Zero handy in case the card needs to be re-cloned or reseated.

---

## 18. Cool Features & Expansion Ideas

This section is for when there's extra time, or for anyone picking up the project in a future semester. These are real, buildable extensions to the Ntry system.

---

### Apple Wallet & Google Wallet Full Integration

The Sprint 4 delivery included a prototype Apple Wallet pass. The full vision: a resident's Ntry credential lives as a persistent pass in Apple Wallet or Google Wallet. The pass displays their room number and the current unlock status. With NFC enabled, they could tap their phone to the door reader directly (bypassing BLE entirely) using the Wallet pass as the credential. This requires provisioning Apple Pass Type IDs (via the Apple Developer portal) and implementing the PassKit web service protocol so passes can be updated (e.g., when access is revoked, the pass becomes invalid).

---

### Video Doorbell Feed in the App

The USB-C camera module is already mounted at the door. Extend it to stream a low-resolution MJPEG video feed that residents and admins can view in the app. When motion is detected (via frame delta analysis in `qr_scanner.py`), push a Firebase Cloud Messaging notification to the resident: "Someone is at your door." The resident can view the live feed in-app and optionally tap Unlock to let them in remotely.

---

### Occupancy Tracking & Smart Notifications

Since Ntry logs every entry and exit, it has the raw data to answer "is anyone in the room right now?" Build an occupancy model: BLE proximity detection at the door means someone entered. Push smart notifications to residents: "Your door has been unlocked — was that you?" Push notifications to admins for unusual access patterns (multiple failed attempts, access at 3 AM). Firebase Cloud Messaging + Cloud Functions make this straightforward.

---

### Multi-Door / Building-Wide Scaling

The current implementation assumes one lock, one M5Stack. The data model (`locks/{lockId}`) already supports multiple locks. To scale to a full building: provision one M5Stack per door, each registered as a separate device in Cloud IoT Core. Residents are assigned to one or more `lockId` values in their `users/` document. Admins get a building-wide map view of all doors with live status.

---

### NFC Tap-to-Unlock

As an alternative to BLE proximity, a resident could tap their NFC-enabled phone to a small NFC tag mounted on the door frame. The tag read triggers the app to wake, pass biometric, and fire the unlock command. This is faster and more precise than BLE (no range ambiguity) and works even on phones with BLE advertising restrictions. Flutter's `flutter_nfc_kit` package handles NFC reading.

---

### Voice Assistant Integration (Siri / Google Assistant)

"Hey Siri, unlock my door." Achievable via Siri Shortcuts (iOS) and App Actions (Android). Create a Shortcut that invokes a custom Intent defined in the Flutter app. The Intent handler calls the same unlock flow as the manual button (biometric auth first, then Firestore write). **The biometric gate is the security-critical piece here** — ensure voice-triggered unlocks still require biometric confirmation.

---

## 19. Team

| Name | Role |
|---|---|
| **Eli Manning** | Team Leader |
| **Elliott Willer** | Developer |
| **Josue Hernandez** | Developer |
| **Johnathan Fierro** | Developer |

**Course:** EGR 302 — Jr. Design Project, Spring 2026
**Instructor:** Dr. Dan Grissom

---

*Last updated: Sprint 4 - 3/19/26*

---

## 20. Planned Features (Sprint 5–6)

---

### Guest Pass Revocation

Residents can revoke an active guest pass from the Guest Management screen. Each guest card has a **Revoke** button. On confirm, the guest document is set to `isRevoked: true` in Firestore. Revoked guests immediately disappear from the resident's list, and their passkey is rejected by the M5Stack QR validator with reason `"revoked"`.

Implementation: `GuestManagementScreen` → revoke icon per card → confirmation dialog → `GuestHelper.revokeGuest(lockId, guestId)` sets `isRevoked: true`. `GuestHelper.streamGuests()` filters out `isRevoked == true` documents.

---

### Lock Location Map Navigation (Guest)

Admins can attach GPS coordinates (`latitude`, `longitude`) to any location via the Location Detail screen. When a guest validates their 6-digit passkey, the QR screen shows a **Get Directions** button if the lock's location has coordinates. Tapping opens Apple Maps (iOS) or Google Maps (Android) navigating directly to the door.

Implementation:
1. `AddLocationScreen` and `LocationDetailScreen` gain optional lat/long fields
2. After passkey validation in `GuestCodeScreen`, load `locks/{lockId}.locationId` → `locations/{locationId}.latitude/longitude`
3. Show "Get Directions" button using `url_launcher` with Apple Maps / Google Maps deep links
4. Button is hidden if no coordinates are set

Required package: `url_launcher`

---

### Firestore Security Rules

Production-ready `firestore.rules` must be deployed from `ntry_backend/` before launch. Rules enforce:
- Residents read only their own `users/` doc; admins read all within their org
- Only admins write to `locks/` and `locations/`
- Residents only write to `locks/{lockId}/pendingCommand` in RTDB for their own lock; M5Stack service account deletes it
- `access_logs/` is append-only; writable by authenticated users and the M5Stack service account; residents may read docs where `lock_id == their assigned lockId`
- `locks/{lockId}/guests/` read/write is scoped to the lock owner

Deploy: `firebase deploy --only firestore:rules`

---

### Cloud Functions — Access Log & Command Validation

Two Cloud Functions in `ntry_backend/functions/`:

1. **`logAccessEvent`** (HTTP callable) — M5Stack calls this after every access event. Writes to `access_logs/{auto-id}` with a server timestamp. Authenticated via M5Stack service account JWT.

2. **`onPendingCommandCreated`** (Firestore trigger) — Fires on any new `locks/{lockId}/pendingCommands/{commandId}`. Validates that `requestedBy` is authorized for the lock. Deletes invalid commands before the M5Stack polls for them.

---

### Lock Management Real-Time Stream

`lock_management_screen.dart` currently uses `FutureBuilder` + pull-to-refresh. This will be converted to `StreamBuilder` using a new `LockHelper.streamByOrg(String org)` method so admins see live lock status changes without manual refresh.
