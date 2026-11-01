/**
 * @file    secrets.example.h
 * @brief   Template for per-device settings that must not be committed.
 *
 *          Copy this file to include/secrets.h (git-ignored) and set your own
 *          values. If secrets.h is missing, the build falls back to this file
 *          and prints a warning. Do not flash the placeholder to a device you
 *          take outside a test bench.
 */

#pragma once

/// SSID broadcast by the device access point.
#define WIFI_AP_SSID  "SwimTrack"

/// WPA2 password for the device access point. Must be 8 to 63 characters.
#define WIFI_AP_PASS  "CHANGE_ME_8_CHARS"
