// App-wide constants for SwimTrack.
// Import this wherever you need API URLs, device names, or default values.

/// Base URL for the ESP32 device REST API.
const String kApiBaseUrl = 'http://192.168.4.1';

/// WiFi SSID broadcast by the SwimTrack device access point.
const String kDeviceSsid =
    String.fromEnvironment('SWIMTRACK_AP_SSID', defaultValue: 'SwimTrack');

/// Optional pre-filled access point password for the connect form.
/// Empty unless the app is built with
/// `--dart-define=SWIMTRACK_AP_PASSWORD=...`. The phone joins the device
/// network through system WiFi settings; the app only checks reachability.
const String kDevicePassword = String.fromEnvironment('SWIMTRACK_AP_PASSWORD');

/// Default pool length in metres used when no preference is saved.
const int kDefaultPoolLength = 25;

/// shared_preferences key for storing the user profile JSON string.
const String kPrefKeyProfile = 'user_profile';

/// shared_preferences key for storing the pool length integer.
const String kPrefKeyPoolLength = 'pool_length';

/// shared_preferences key for storing the simulator mode boolean.
const String kPrefKeySimulatorMode = 'simulator_mode';