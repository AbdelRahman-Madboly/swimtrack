/**
 * @file    config.h
 * @brief   SwimTrack Sender: configuration header.
 *
 *          Everything else (WiFi, session storage, stroke/lap thresholds)
 *          is intentionally omitted - those run on the laptop from CSV data,
 *          not on the sender device.
 *
 *          Target hardware: LOLIN S2 Mini (ESP32-S2) + GY-6500 (MPU-6500)
 *          I2C:             SCL=GPIO33, SDA=GPIO34
 */

#pragma once

#include <Arduino.h>

// ============================================================
//  DEBUG OUTPUT
// ============================================================

#define DEBUG_SERIAL 1

#if DEBUG_SERIAL
  #define DBG(tag, fmt, ...) Serial.printf("[" tag "] " fmt "\n", ##__VA_ARGS__)
#else
  #define DBG(tag, fmt, ...) do {} while(0)
#endif

// ============================================================
//  PIN ASSIGNMENTS  - LOLIN S2 Mini
// ============================================================

#define PIN_I2C_SCL       33    ///< I2C clock → GY-6500 SCL
#define PIN_I2C_SDA       34    ///< I2C data  → GY-6500 SDA
#define PIN_LED           15    ///< S2 Mini built-in LED
#define PIN_BUTTON         0    ///< BOOT button (active LOW, internal pull-up)

// ============================================================
//  I2C / MPU INTERFACE
// ============================================================

#define I2C_CLOCK_HZ      400000UL

#define MPU6500_I2C_ADDR  0x68

#define MPU_WHO_AM_I_VAL  0x70   ///< MPU-6500 expected value

// ============================================================
//  MPU REGISTER MAP
// ============================================================

#define MPU_REG_SMPLRT_DIV    0x19
#define MPU_REG_CONFIG        0x1A
#define MPU_REG_GYRO_CONFIG   0x1B
#define MPU_REG_ACCEL_CONFIG  0x1C
#define MPU_REG_ACCEL_XOUT_H  0x3B
#define MPU_REG_TEMP_OUT_H    0x41
#define MPU_REG_WHO_AM_I      0x75
#define MPU_REG_PWR_MGMT_1    0x6B

// ============================================================
//  IMU RANGE SETTINGS
//  ±8g  @ 4096 LSB/g   (AFS_SEL = 2)
//  ±1000dps @ 32.8 LSB/dps (FS_SEL = 2)
// ============================================================

#define ACCEL_FS_SEL        2
#define ACCEL_SENSITIVITY   4096.0f   ///< LSB per g at ±8g
#define GYRO_FS_SEL         2
#define GYRO_SENSITIVITY    32.8f     ///< LSB per dps at ±1000dps

// ============================================================
//  SAMPLING
// ============================================================

#define SAMPLE_RATE_HZ    50
#define SAMPLE_PERIOD_MS  (1000UL / SAMPLE_RATE_HZ)   ///< 20 ms

// ============================================================
//  EMA FILTER
// ============================================================

#define EMA_ALPHA         0.3f    ///< Smoothing factor for mag filter

// ============================================================
//  ESP-NOW
// ============================================================

/// ESP-NOW peer address. The default is the broadcast address, which reaches
/// any receiver listening on the same channel without pairing (no delivery
/// acknowledgement). To unicast to one receiver, copy
/// src/config_local.example.h to src/config_local.h (git-ignored) and set the
/// MAC that the receiver prints on boot.
#if __has_include("config_local.h")
  #include "config_local.h"
#endif

#ifndef ESPNOW_PEER_MAC
  #define ESPNOW_PEER_MAC  { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }
#endif

/// WiFi channel for ESP-NOW. Both sender and receiver must use the same channel.
/// Channel 1 is the safest default - change both if you have interference.
#define ESPNOW_WIFI_CHANNEL   1

// ============================================================
//  CALIBRATION
// ============================================================

/// Number of IMU samples to average during the boot still-period.
/// At 50 Hz, 150 samples = 3 seconds. Device must be completely still.
#define CALIB_SAMPLE_COUNT    150

// ============================================================
//  LED BEHAVIOUR
// ============================================================

/// Brief LED flash duration on each successful ESP-NOW send [ms].
/// 2 ms is barely visible but confirms the send loop is running.
#define ESPNOW_SEND_LED_MS    2

// ============================================================
//  STATS PRINT INTERVAL
// ============================================================

#define STATS_INTERVAL_MS     5000UL  ///< Print send-rate stats every 5 s
