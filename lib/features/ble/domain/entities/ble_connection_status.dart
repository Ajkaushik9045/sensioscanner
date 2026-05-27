/// Extended BLE connection state machine.
///
/// Flutter_reactive_ble only has 4 states: connecting/connected/disconnecting/
/// disconnected. We add [discovering] and [ready] to track the GATT phase
/// after transport-level connection, giving the UI fine-grained feedback.
///
/// State transitions:
/// ```
///  ┌──────────────┐     transport     ┌───────────────┐
///  │  connecting  │ ────────────────► │   connected   │
///  └──────────────┘                   └───────────────┘
///                                           │ GATT discovery starts
///                                           ▼
///                                    ┌─────────────┐
///                                    │ discovering │
///                                    └─────────────┘
///                                           │ services found
///                                           ▼
///                                       ┌───────┐
///                                       │ ready │ ◄── normal operating state
///                                       └───────┘
///                                           │ user disconnect or link loss
///                                           ▼
///                                  ┌──────────────────┐
///                                  │  disconnecting   │
///                                  └──────────────────┘
///                                           │
///                                           ▼
///                                  ┌──────────────────┐
///                                  │   disconnected   │
///                                  └──────────────────┘
///
///  Any state ──── unrecoverable error ────► error
/// ```
enum BleConnectionStatus {
  /// Actively attempting to establish transport-level connection.
  connecting,

  /// Transport connected; GATT services not yet discovered.
  connected,

  /// GATT service discovery is in progress (may take 1–5 s on slow peripherals).
  discovering,

  /// All services discovered; device is ready for characteristic operations.
  ready,

  /// Clean disconnection in progress (user-initiated).
  disconnecting,

  /// Device is disconnected (cleanly or after link loss).
  disconnected,

  /// Unrecoverable error; the connection must be re-established from scratch.
  error;

  // ── Convenience predicates ─────────────────────────────────────────────────

  /// True while the device is in an active connection phase.
  bool get isActive =>
      this == connecting ||
      this == connected ||
      this == discovering ||
      this == ready;

  /// True when no further events will be emitted for this connection.
  bool get isTerminal => this == disconnected || this == error;

  /// True when characteristic operations (subscribe, read, write) are allowed.
  bool get canOperateCharacteristics => this == ready;

  /// Human-readable label for UI display.
  String get label => switch (this) {
        connecting => 'Connecting…',
        connected => 'Connected',
        discovering => 'Discovering services…',
        ready => 'Ready',
        disconnecting => 'Disconnecting…',
        disconnected => 'Disconnected',
        error => 'Connection error',
      };
}
