/**
 * @file    mpu6500.cpp
 * @brief   IMU driver implementation for SwimTrack Sender.
 *
 *          MPU-6500 specifics applied here:
 *            WHO_AM_I expected : 0x70
 *            Temperature       : °C = raw / 333.87 + 21.0   ← MPU-6500 formula
 *            Accel range       : ±8g  (AFS_SEL=2)
 *            Gyro range        : ±1000dps (FS_SEL=2)
 *
 *          NOTE: The old code used raw/340.0+36.53 (MPU-6050 formula).
 *          That has been corrected here. Always use raw/333.87+21.0 for MPU-6500.
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#include "mpu6500.h"

// ============================================================
//  CONSTRUCTOR
// ============================================================

MPU6500::MPU6500()
    : _initialised(false), _whoAmI(0x00)
{
}

// ============================================================
//  begin()
// ============================================================

bool MPU6500::begin()
{
    // 1. Start I2C bus
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    Wire.setClock(I2C_CLOCK_HZ);
    DBG("IMU", "I2C started - SDA=%d SCL=%d @ %lu Hz",
        PIN_I2C_SDA, PIN_I2C_SCL, I2C_CLOCK_HZ);

    // 2. Wake from sleep
    if (!writeRegister(MPU_REG_PWR_MGMT_1, 0x00)) {
        DBG("IMU", "ERROR: PWR_MGMT_1 wake write failed");
        return false;
    }
    delay(100);

    // 3. PLL gyro clock
    if (!writeRegister(MPU_REG_PWR_MGMT_1, 0x01)) {
        DBG("IMU", "ERROR: PWR_MGMT_1 PLL write failed");
        return false;
    }

    // 4. WHO_AM_I check
    if (!readRegister(MPU_REG_WHO_AM_I, _whoAmI)) {
        DBG("IMU", "ERROR: WHO_AM_I read failed");
        return false;
    }
    DBG("IMU", "WHO_AM_I = 0x%02X (expected 0x%02X)", _whoAmI, MPU_WHO_AM_I_VAL);

    if (_whoAmI != MPU_WHO_AM_I_VAL) {
        DBG("IMU", "ERROR: WHO_AM_I mismatch - wrong chip or I2C address?");
        return false;
    }

    // 5. DLPF_CFG=3 → accel BW=44Hz, gyro BW=42Hz, ODR=1kHz
    if (!writeRegister(MPU_REG_CONFIG, 0x03)) {
        DBG("IMU", "ERROR: CONFIG write failed");
        return false;
    }

    // 6. Sample rate: 1000 / (1 + SMPLRT_DIV) = 50 Hz → SMPLRT_DIV=19=0x13
    const uint8_t smplrtDiv = static_cast<uint8_t>((1000u / SAMPLE_RATE_HZ) - 1u);
    if (!writeRegister(MPU_REG_SMPLRT_DIV, smplrtDiv)) {
        DBG("IMU", "ERROR: SMPLRT_DIV write failed");
        return false;
    }
    DBG("IMU", "SMPLRT_DIV=%d → %d Hz", smplrtDiv, SAMPLE_RATE_HZ);

    // 7. Gyro full-scale: FS_SEL bits [4:3]
    const uint8_t gyroConfig = static_cast<uint8_t>(GYRO_FS_SEL << 3);
    if (!writeRegister(MPU_REG_GYRO_CONFIG, gyroConfig)) {
        DBG("IMU", "ERROR: GYRO_CONFIG write failed");
        return false;
    }
    DBG("IMU", "Gyro FS_SEL=%d → ±%d dps", GYRO_FS_SEL, 250 << GYRO_FS_SEL);

    // 8. Accel full-scale: AFS_SEL bits [4:3]
    const uint8_t accelConfig = static_cast<uint8_t>(ACCEL_FS_SEL << 3);
    if (!writeRegister(MPU_REG_ACCEL_CONFIG, accelConfig)) {
        DBG("IMU", "ERROR: ACCEL_CONFIG write failed");
        return false;
    }
    DBG("IMU", "Accel AFS_SEL=%d → ±%d g", ACCEL_FS_SEL, 2 << ACCEL_FS_SEL);

    _initialised = true;
    DBG("IMU", "MPU-6500 ready. Accel=±%dg  Gyro=±%ddps  Rate=%dHz",
        (2 << ACCEL_FS_SEL), (250 << GYRO_FS_SEL), SAMPLE_RATE_HZ);
    return true;
}

// ============================================================
//  read()
// ============================================================

bool MPU6500::read(IMUSample& sample)
{
    Wire.beginTransmission(MPU6500_I2C_ADDR);
    Wire.write(MPU_REG_ACCEL_XOUT_H);
    if (Wire.endTransmission(false) != 0) {
        DBG("IMU", "ERROR: I2C TX failed in read()");
        return false;
    }

    const uint8_t bytesExpected = 14;
    uint8_t received = Wire.requestFrom(
        static_cast<uint8_t>(MPU6500_I2C_ADDR), bytesExpected);

    if (received < bytesExpected) {
        DBG("IMU", "ERROR: short read - got %d of %d bytes", received, bytesExpected);
        while (Wire.available()) { Wire.read(); }
        return false;
    }

    // Big-endian signed 16-bit pairs: AX AY AZ TEMP GX GY GZ
    auto readWord = [&]() -> int16_t {
        uint8_t hi = static_cast<uint8_t>(Wire.read());
        uint8_t lo = static_cast<uint8_t>(Wire.read());
        return static_cast<int16_t>((static_cast<uint16_t>(hi) << 8) | lo);
    };

    const int16_t rawAx   = readWord();
    const int16_t rawAy   = readWord();
    const int16_t rawAz   = readWord();
    const int16_t rawTemp = readWord();
    const int16_t rawGx   = readWord();
    const int16_t rawGy   = readWord();
    const int16_t rawGz   = readWord();

    sample.ax     = static_cast<float>(rawAx) / ACCEL_SENSITIVITY;
    sample.ay     = static_cast<float>(rawAy) / ACCEL_SENSITIVITY;
    sample.az     = static_cast<float>(rawAz) / ACCEL_SENSITIVITY;
    sample.gx     = static_cast<float>(rawGx) / GYRO_SENSITIVITY;
    sample.gy     = static_cast<float>(rawGy) / GYRO_SENSITIVITY;
    sample.gz     = static_cast<float>(rawGz) / GYRO_SENSITIVITY;

    // ── MPU-6500 temperature formula (CORRECTED) ──────────────
    // Old (wrong, MPU-6050): raw / 340.0 + 36.53
    // Correct (MPU-6500)  : raw / 333.87 + 21.0
    sample.temp_c = static_cast<float>(rawTemp) / 333.87f + 21.0f;

    sample.timestamp = millis();
    return true;
}

// ============================================================
//  STATUS ACCESSORS
// ============================================================

uint8_t MPU6500::whoAmI() const      { return _whoAmI; }
bool    MPU6500::isInitialised() const { return _initialised; }

// ============================================================
//  PRIVATE - I2C HELPERS
// ============================================================

bool MPU6500::writeRegister(uint8_t reg, uint8_t value)
{
    Wire.beginTransmission(MPU6500_I2C_ADDR);
    Wire.write(reg);
    Wire.write(value);
    return (Wire.endTransmission(true) == 0);
}

bool MPU6500::readRegister(uint8_t reg, uint8_t& value)
{
    Wire.beginTransmission(MPU6500_I2C_ADDR);
    Wire.write(reg);
    if (Wire.endTransmission(false) != 0) return false;

    const uint8_t received = Wire.requestFrom(
        static_cast<uint8_t>(MPU6500_I2C_ADDR),
        static_cast<uint8_t>(1));
    if (received < 1) return false;

    value = static_cast<uint8_t>(Wire.read());
    return true;
}