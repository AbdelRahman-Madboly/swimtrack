/**
 * @file    sensor_packet.h
 * @brief   SwimTrack - ESP-NOW packet definition shared between sender and receiver.
 *
 *          COPY THIS FILE UNCHANGED into both projects:
 *            swimtrack-sender/src/sensor_packet.h
 *            swimtrack-receiver/src/sensor_packet.h
 *
 *          The struct is packed to avoid padding differences between compilers.
 *          Total size: 4+4+4+4+4+4+4+4+4+1 = 37 bytes.
 *          Well within the ESP-NOW 250-byte payload limit.
 *
 *          Field notes:
 *            ts_ms    - device millis() at the moment the sample was captured
 *                       (not the send time). Use this for inter-sample timing.
 *            ax/ay/az - calibrated accel [g]  (offsets applied on sender)
 *            gx/gy/gz - calibrated gyro [dps] (offsets applied on sender)
 *            temp_c   - MPU-6500 die temperature [°C]
 *            mag_raw  - sqrtf(ax²+ay²+az²) computed on sender before EMA
 *            seq      - rolling 0–255 counter; receiver uses gaps to detect drops
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#pragma once

#include <stdint.h>

struct __attribute__((packed)) SensorPacket {
    uint32_t ts_ms;     ///< Device timestamp [ms since boot]
    float    ax;        ///< Accel X [g]   - offset-corrected
    float    ay;        ///< Accel Y [g]   - offset-corrected
    float    az;        ///< Accel Z [g]   - offset-corrected
    float    gx;        ///< Gyro  X [dps] - offset-corrected
    float    gy;        ///< Gyro  Y [dps] - offset-corrected
    float    gz;        ///< Gyro  Z [dps] - offset-corrected
    float    temp_c;    ///< Die temperature [°C]
    float    mag_raw;   ///< sqrtf(ax²+ay²+az²) before EMA [g]
    uint8_t  seq;       ///< Sequence counter 0–255 (rolls over)
};
// static_assert(sizeof(SensorPacket) == 37, "SensorPacket size mismatch");
