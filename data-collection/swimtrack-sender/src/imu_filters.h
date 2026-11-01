/**
 * @file    imu_filters.h
 * @brief   IMU signal filtering for SwimTrack Sender.
 *
 *          EMA formula:  y[n] = alpha * x[n] + (1 - alpha) * y[n-1]
 *          alpha = 0.3 recommended for stroke detection (EMA_ALPHA in config.h)
 *
 *          Copied unchanged from swimtrack v1.0.0.
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#pragma once

#include <Arduino.h>
#include <math.h>
#include "config.h"

struct IMUSample;

// ============================================================
//  EMA LOW-PASS FILTER
// ============================================================

class EMAFilter {
public:
    explicit EMAFilter(float alpha = EMA_ALPHA);

    float update(float input);
    void  reset(float seedValue = 0.0f);
    float value() const { return _prev; }
    void  setAlpha(float alpha);
    float alpha() const { return _alpha; }

private:
    float _alpha;
    float _prev;
    bool  _seeded;
};

// ============================================================
//  FREE FUNCTIONS
// ============================================================

float accelMagnitude(float ax, float ay, float az);
float accelMagnitude(const IMUSample& s);
float filteredMagnitude(EMAFilter& filter, float ax, float ay, float az);