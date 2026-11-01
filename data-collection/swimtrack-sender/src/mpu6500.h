/**
 * @file    mpu6500.h
 * @brief   IMU driver interface for SwimTrack Sender.
 *
 *          Declares the IMUSample data structure and the MPU6500 driver class.
 *          Targets the MPU-6500 (GY-6500 module) on LOLIN S2 Mini.
 *
 *          Chip configuration:
 *            WHO_AM_I  : 0x70
 *            Temp formula: raw / 333.87 + 21.0  (MPU-6500 formula)
 *            Accel range : ±8g  (AFS_SEL=2, sensitivity=4096 LSB/g)
 *            Gyro range  : ±1000dps (FS_SEL=2, sensitivity=32.8 LSB/dps)
 *
 *          I2C pins: SCL=GPIO33, SDA=GPIO34 (defined in config.h)
 *          I2C address: 0x68 (AD0 low)
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#pragma once

#include <Arduino.h>
#include <Wire.h>
#include "config.h"

// ============================================================
//  IMU DATA STRUCTURE
// ============================================================

/**
 * @brief One fully-converted IMU sample.
 *
 *  ax, ay, az  - linear acceleration [g]      (1 g ≈ 9.81 m/s²)
 *  gx, gy, gz  - angular velocity    [dps]    (degrees per second)
 *  temp_c      - die temperature      [°C]
 *  timestamp   - millis() at capture  [ms since boot]
 */
struct IMUSample {
    float    ax;         ///< Accel X  [g]
    float    ay;         ///< Accel Y  [g]
    float    az;         ///< Accel Z  [g]
    float    gx;         ///< Gyro  X  [dps]
    float    gy;         ///< Gyro  Y  [dps]
    float    gz;         ///< Gyro  Z  [dps]
    float    temp_c;     ///< Die temperature [°C]
    uint32_t timestamp;  ///< Capture time [ms]
};

// ============================================================
//  MPU6500 DRIVER CLASS
// ============================================================

/**
 * @brief I2C driver for the InvenSense MPU-6500 IMU.
 *
 *  Handles sensor wake-up, register configuration, WHO_AM_I verification,
 *  and 14-byte burst reads converted to physical units.
 *
 * Typical usage:
 * @code
 *   MPU6500 imu;
 *   if (!imu.begin()) { // halt }
 *
 *   IMUSample s;
 *   if (imu.read(s)) {
 *       Serial.printf("az = %.3f g\n", s.az);
 *   }
 * @endcode
 */
class MPU6500 {
public:

    MPU6500();

    /**
     * @brief Initialise the IMU over I2C.
     *        Wakes sensor, selects PLL clock, verifies WHO_AM_I,
     *        sets DLPF, sample rate divider, gyro and accel ranges.
     * @return true on success, false on WHO_AM_I mismatch or I2C error.
     */
    bool begin();

    /**
     * @brief Burst-read 14 bytes from register 0x3B and convert.
     * @param sample  Output: filled with converted values and millis() timestamp.
     * @return true on a successful 14-byte read, false on I2C error.
     */
    bool read(IMUSample& sample);

    /** @return Cached WHO_AM_I byte (0x70 for MPU-6500). */
    uint8_t whoAmI() const;

    /** @return true if begin() completed successfully. */
    bool isInitialised() const;

private:
    bool writeRegister(uint8_t reg, uint8_t value);
    bool readRegister(uint8_t reg, uint8_t& value);

    bool    _initialised;
    uint8_t _whoAmI;
};