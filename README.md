# SensioScanner 🩺📡

SensioScanner is a production-grade Flutter application built using **Clean Architecture** and the **BLoC state management pattern**. It allows users to scan for nearby Bluetooth Low Energy (BLE) devices, view connection history, connect to peripherals, negotiate MTUs, discover GATT services/characteristics, and stream/visualise real-time health telemetry (vitals).

---

## 📱 Features

1. **Active Scan & Filtering**:
   - Deduplicated scan list sorted by RSSI signal strength in real-time.
   - Dynamic UI filters for device name matching and RSSI threshold (e.g., strong signals only, $\ge -70$ dBm).
   - Dynamic handling of system Bluetooth and Location states (enabling Bluetooth natively inside the app on Android).
2. **Dynamic GATT Explorer**:
   - Deep inspection of all services, characteristics, properties (Read, Write, Notify, Indicate), and UUIDs.
   - Live stream subscription toggle for any individual notifiable characteristic.
3. **Multi-Stream Vitals Dashboard**:
   - Detects **SensioVital** devices (via name match or custom service UUID `12345678-1234-4678-8234-56789abcdef0`).
   - Automatically subscribes to all available vitals (Heart Rate, SpO₂, Temperature, Battery) and displays them concurrently in a premium dashboard.
   - Renders a real-time sparkline chart (sliding window of last 20 samples) for each active stream.
4. **Reliable Connection Lifecycle**:
   - **Auto-Reconnect**: Exponential backoff reconnect logic (1s, 2s, 4s) up to 3 attempts on unexpected disconnects.
   - **GATT 133 Protection**: Automatic detection of Android's infamous GATT 133 error, triggering a clean disconnect, 600ms delay, and silent retry.
   - **MTU Negotiation**: Automatically requests a 512-byte MTU upon connection to optimize payload transfer sizes.
5. **Connection History**:
   - Local persistence of previously connected devices (storing IDs, names, and timestamps) using `shared_preferences`.

---

## 🏛️ Architecture Overview

The codebase is built on **Clean Architecture** principles, maintaining a strict separation of concerns to allow easy unit testing and library swapping:

```
lib/
├── core/
│   ├── di/                 # Dependency Injection (GetIt service locator)
│   ├── error/              # Domain Failures mapping
│   ├── router/             # Shell navigation routing (GoRouter)
│   ├── services/           # Permission service & BLE UUID mapper
│   └── theme/              # Premium Dark/Light theme design system
└── features/
    ├── ble/                # Core BLE Domain/Data bridge (independent of other features)
    ├── scanner/            # Scan & Filter UI + BLoC logic
    ├── device_detail/      # GATT discovery, vitals parsing, multi-stream dashboard + BLoC logic
    └── history/            # Connection history list & local repository persistence
```

### Clean Architecture Layers:
*   **Domain Layer**: Pure Dart containing Entities, Repository contracts (`IBleRepository`), and Use Cases. Free from UI or hardware framework dependencies.
*   **Data Layer**: Framework-specific implementations, including `BleRepositoryImpl` (which wraps `flutter_reactive_ble`) and `HistoryRepositoryImpl` (which wraps `shared_preferences`).
*   **Presentation Layer**: Governed by `flutter_bloc` BLoCs (`ScannerBloc`, `DeviceDetailBloc`). States are converted to visually appealing widgets with custom animations, glassmorphism containers, and reactive status banners.

---

## ⚙️ Setup & Installation

### Requirements
*   **Flutter SDK**: `^3.12.0`
*   **Dart SDK**: `^3.12.0`
*   **Android**: API Level 21+ (Android 10+ recommended). Permissions for `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, and `ACCESS_FINE_LOCATION` are handled dynamically.
*   **iOS**: Deployment target 11.0+ with `NSBluetoothAlwaysUsageDescription` set in `Info.plist`.

### Building and Running the App
1. Clone this repository.
2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```
4. For generating a Release APK:
   ```bash
   flutter build apk --release
   ```
   *The output APK will be located in `build/app/outputs/flutter-apk/app-release.apk`.*


## 🔌 flutter_reactive_ble Usage & Implementations

Our data-layer implementation ([ble_repository_impl.dart](file:///home/kaushik/Documents/sensioscanner/lib/features/ble/data/repositories/ble_repository_impl.dart)) acts as a wrapper around `flutter_reactive_ble`:

*   **Scan Management**:
    Scans are initiated via `scanForDevices()`. A critical Android fix is applied here:
    ```dart
    // Android BLE stability: cancel previous scan and wait 250ms
    // before starting a new scan to avoid SCAN_FAILED_ALREADY_STARTED.
    await stopScan();
    await Future.delayed(const Duration(milliseconds: 250));
    ```
*   **Connection and Collision Avoidance**:
    Scanning and connecting simultaneously causes connection hangs. We explicitly stop active scans before calling `connectToDevice()`:
    ```dart
    controller.onListen = () async {
      await stopScan(); // Prevent connection hangs on Android
      _ble.connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 10));
    };
    ```
*   **GATT Service Discovery**:
    Uses the modern, non-deprecated flutter_reactive_ble API to discover and parse services and characteristics:
    ```dart
    await _ble.discoverAllServices(deviceId).timeout(timeout);
    final services = await _ble.getDiscoveredServices(deviceId);
    ```
*   **Backpressure & Throttling (rxdart)**:
    High-frequency sensors (e.g. IMUs or medical probes emitting at 100Hz+) can flood the Dart event loop, locking up the UI thread. We apply a 50ms throttle buffer to incoming notifications:
    ```dart
    _ble.subscribeToCharacteristic(characteristic)
        .throttleTime(const Duration(milliseconds: 50), leading: true, trailing: false)
    ```

---

## ⚠️ Issues Faced & Solutions

1. **Kotlin Gradle Plugin Migration Warning**:
   *   *Issue*: When building, a warning about Kotlin Gradle Plugin migration is displayed by Gradle due to `flutter_reactive_ble`'s internal dependency (`reactive_ble_mobile`).
   *   *Solution*: This warning is a compilation-time notice from the package dependency. It does **not** impact app performance, runtime stability, or release APK generation.
2. **GATT 133 Error on Android**:
   *   *Issue*: Android devices frequently throw status code `133` during connection handshakes due to stale GATT cache tables in the OS.
   *   *Solution*: Intercepted connection errors in the BLoC. If `133` or `GATT_ERROR` is detected, the BLoC closes the connection, waits for 600ms (letting the OS clear its connection tables), and automatically retries.
3. **Simultaneous Scan and Connect Hangs**:
   *   *Issue*: Attempting to connect to a peripheral while a BLE scan is running leads to connection timeouts on several Android 10+ devices.
   *   *Solution*: Ensured `stopScan()` executes and awaits completion before invoking `connectToDevice()`.

---

## 🎓 Key Learnings, Observations & Discoveries

1. **GATT Protocol Architecture**:
   *   Deepened understanding of the Generic Attribute Profile (GATT) hierarchy. Peripherals act as a GATT Server containing Services, which group multiple Characteristics. Each Characteristic contains UUID descriptors, values, and access properties (read, write, notify, indicate).
2. **Application-Layer Security**:
   *   BLE link-layer security (pairing/bonding) can be bypassable or absent on low-cost medical and IoT devices. As a result, sensitive medical telemetry (like heart rate and SpO₂) should be encrypted or verified at the **application layer** (using symmetric AES payloads or token handshakes) rather than relying solely on BLE encryption.
3. **Single Radio Scan Limitations**:
   *   Learned that mobile chipsets share a single radio/antenna between Wi-Fi, Classic Bluetooth, and BLE. As a result, you cannot run a Classic Bluetooth scan and a BLE scan simultaneously without severe degradation in RSSI accuracy, latency, and packet loss. Single-mode scheduling is required.

---

## 🚀 Additional Features & Experiments Explored

1. **Connection History Persistence**:
   - Saves previous device connections (`id`, `name`, and connection `timestamp`) locally using `shared_preferences`.
   - Enables users to view, track, and instantly initiate connections to previously discovered/connected peripherals without waiting for a fresh scan broadcast.
2. **Real-time Search & Signal Strength Filtering**:
   - Integrates dynamic text-based search (name query matching) and RSSI signal-strength threshold slider filtering within the scanner BLoC.
   - Optimizes usability in noise-heavy or high-density BLE environments by filtering out low-signal/unnamed background beacons.

---

## 🛠️ Improvements I Would Make with More Time

1. **Proper Generic Multi-Device Connectivity**:
   - Refactor the BLE layer and data parser to be fully generic instead of hardcoded to specific services.
   - Allow simultaneous connection to multiple devices (e.g. smart rings, heart rate bands, and smart scales) at the same time.
2. **Unified Vitals Dashboard**:
   - Develop a centralized dashboard to track and display real-time telemetry from all connected devices simultaneously.
   - Enable cross-device telemetry correlation (e.g. graphing heart rate from device A alongside SpO₂ from device B) on a single screen.

---

## 📈 Scalability & Future Roadmap

If deploying this application to a real-world production environment with hundreds of diverse medical/IoT devices, we would implement the following scaling strategies:

1. **Dynamic JSON Device Profiles**:
   *   Rather than hardcoding UUIDs and parsing algorithms (like `vital_sign_parser.dart`), fetch **Device Profiles** dynamically from a secure REST API. These JSON/Protobuf profiles would define:
       - Which services/characteristics to discover.
       - Byte-level parsing rules (offset, length, bit-masks, endianness, multipliers).
       - Custom UI styling mapping (colors, icons, names) for each sensor.

2. **Background Syncing & Foreground Services**:
   *   Use Android Foreground Services (with notification) and iOS CoreBluetooth Background Mode to maintain GATT connection streams even when the app is minimized or the device is locked, pushing emergency alerts if vitals exceed critical thresholds.
