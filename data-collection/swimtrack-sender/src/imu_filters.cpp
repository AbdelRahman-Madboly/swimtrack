/**
 * @file    imu_filters.cpp
 * @brief   IMU signal filtering implementation for SwimTrack Sender.
 *          Copied unchanged from swimtrack v1.0.0.
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#include "imu_filters.h"
#include "mpu6500.h"

// ============================================================
//  EMAFilter
// ============================================================

EMAFilter::EMAFilter(float alpha)
    : _prev(0.0f), _seeded(false)
{
    setAlpha(alpha);
}

float EMAFilter::update(float input)
{
    if (!_seeded) {
        _prev   = input;
        _seeded = true;
        return _prev;
    }
    _prev = _alpha * input + (1.0f - _alpha) * _prev;
    return _prev;
}

void EMAFilter::reset(float seedValue)
{
    _prev   = seedValue;
    _seeded = (seedValue != 0.0f);
}

void EMAFilter::setAlpha(float alpha)
{
    if      (alpha <= 0.0f) _alpha = 0.01f;
    else if (alpha >  1.0f) _alpha = 1.0f;
    else                    _alpha = alpha;
}

// ============================================================
//  FREE FUNCTIONS
// ============================================================

float accelMagnitude(float ax, float ay, float az)
{
    return sqrtf(ax * ax + ay * ay + az * az);
}

float accelMagnitude(const IMUSample& s)
{
    return accelMagnitude(s.ax, s.ay, s.az);
}

float filteredMagnitude(EMAFilter& filter, float ax, float ay, float az)
{
    return filter.update(accelMagnitude(ax, ay, az));
}