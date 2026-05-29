import Foundation

/// Centralized UserDefaults keys to avoid scattered string literals.
enum UDKey {
    static let speedThreshold      = "stopphone_speed_threshold"
    static let isEnabled           = "stopphone_is_enabled"
    static let aboveThreshold      = "stopphone_above_threshold"
    static let isBlocking          = "stopphone_is_blocking"
    static let totalBlock          = "stopphone_total_block"
    static let blockingSelection   = "stopphone_blocking_selection"
    static let btTrigger           = "stopphone_bt_trigger"
    static let btDevice            = "stopphone_bt_device"
    // New
    static let voiceAlertEnabled   = "stopphone_voice_alert"
    static let passengerUntil      = "stopphone_passenger_until"   // TimeInterval since 1970
    static let autoDisableMinutes  = "stopphone_auto_disable_min"  // 0 = off
    static let lastMotionTimestamp = "stopphone_last_motion_ts"
    static let parentPIN           = "stopphone_parent_pin"        // 4 digits, plain (low value secret)
    static let trips               = "stopphone_trips"             // JSON-encoded [Trip]
    static let lastNotifTimestamp  = "stopphone_last_notif_ts"
}

/// Tunable numeric constants in one place.
enum AppConstants {
    /// Anti-flutter: deactivate only when speed drops this many km/h below the threshold.
    static let hysteresisGap: Double = 5.0
    /// Below this GPS speed (km/h) we consider the device stationary (filters jitter).
    static let speedNoiseFloor: Double = 2.0
    /// Minimum delay between two driving notifications (seconds).
    static let notificationCooldown: TimeInterval = 30
    /// Default passenger snooze duration (seconds).
    static let passengerSnoozeDuration: TimeInterval = 15 * 60
    /// GPS distance filter (meters). Good balance: enough resolution for car speeds, easy on battery.
    static let gpsDistanceFilter: Double = 10
    /// Default speed threshold (km/h) on first launch.
    static let defaultSpeedThreshold: Double = 15
    /// Trip is recorded only if duration exceeds this (seconds) — filters phantom blocks from BT/GPS jitter.
    static let minTripDuration: TimeInterval = 30
    /// Auto-disable options in minutes (0 = disabled).
    static let autoDisableOptions: [Int] = [0, 15, 30, 60, 120]
}
