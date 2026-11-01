/**
 * @file    stroke_detector.h
 * @brief   Swim stroke detection for SwimTrack.
 *
 *          Detects individual strokes from the filtered acceleration magnitude
 *          with a two-state FSM (BELOW / ABOVE threshold) and a dynamic
 *          baseline that slowly tracks the gravity level.
 *
 *          Algorithm:
 *            - A slow EMAFilter (BASELINE_ALPHA = 0.02) tracks the quiet
 *              magnitude. It is updated only in the BELOW state so arm-swing
 *              peaks do not lift the baseline.
 *            - Dynamic threshold = baseline + STROKE_THRESHOLD_G.
 *            - BELOW -> ABOVE when filtMag > threshold and at least
 *              STROKE_MIN_GAP_MS have passed since the last stroke.
 *            - A stroke is counted on the ABOVE -> BELOW falling edge.
 *            - Stroke rate (spm) is the mean of the last STROKE_RATE_WINDOW
 *              inter-stroke intervals.
 *
 *          Stroke style:
 *            On every counted stroke a depth-2 decision tree classifies the
 *            last 50 samples (1 s at 50 Hz) as FREESTYLE or BACKSTROKE:
 *                ax_min <= -0.35                      -> BACKSTROKE
 *                ax_min >  -0.35 and gx_max <= 482.42 -> FREESTYLE
 *                ax_min >  -0.35 and gx_max >  482.42 -> BACKSTROKE
 *            The split values came from one dry-land session. That dataset is
 *            not part of this repository and the tree has not been tested in
 *            water. Breaststroke and butterfly are not classified.
 */

#pragma once

#include <Arduino.h>
#include "config.h"
#include "imu_filters.h"

/** Number of recent inter-stroke intervals used to compute stroke rate. */
#ifndef STROKE_RATE_WINDOW
  #define STROKE_RATE_WINDOW  5
#endif

/** Alpha for the slow EMA baseline tracker (gravity level estimation). */
#ifndef BASELINE_ALPHA
  #define BASELINE_ALPHA  0.02f
#endif

/** Classifier split values (see file header). */
#define CLASSIFIER_AX_MIN_SPLIT_G    (-0.35f)
#define CLASSIFIER_GX_MAX_SPLIT_DPS  (482.42f)

/**
 * @brief Swimming stroke style. BREASTSTROKE and BUTTERFLY are reserved and
 *        are never produced by the current classifier.
 */
enum class StrokeType : uint8_t {
    UNKNOWN      = 0,
    FREESTYLE    = 1,
    BACKSTROKE   = 2,
    BREASTSTROKE = 3,
    BUTTERFLY    = 4
};

/** @brief Upper-case name for a StrokeType, e.g. "FREESTYLE". */
const char* strokeTypeName(StrokeType t);

/**
 * @brief Detects individual swim strokes from filtered accel magnitude.
 *
 * @code
 *   StrokeDetector det;
 *   det.begin();
 *   // In the 50 Hz sample loop:
 *   if (det.update(filtMag, sample.ax, sample.gx, millis())) { ... }
 * @endcode
 */
class StrokeDetector {
public:
    StrokeDetector();

    /** Reset all state and seed the baseline to 1.0 g. Call at session start. */
    void begin();

    /**
     * @brief Feed one sample into the detector.
     *
     * @param filtMag  EMA-filtered accel magnitude [g].
     * @param ax       Accelerometer X axis [g], classifier input.
     * @param gx       Gyroscope X axis [dps], classifier input. This is the
     *                 axis the decision tree was fitted on.
     * @param nowMs    Current millis() timestamp.
     * @return true if a stroke was counted on this sample.
     */
    bool update(float filtMag, float ax, float gx, uint32_t nowMs);

    uint32_t   strokeCount() const;     ///< Strokes since begin() or reset()
    float      strokeRateSpm() const;   ///< Mean rate [spm], 0 until two strokes
    uint32_t   lastStrokeTime() const;  ///< millis() of last stroke, 0 if none
    StrokeType strokeType() const;      ///< Style of the most recent stroke
    float      baseline() const;        ///< Current baseline [g]
    float      threshold() const;       ///< baseline() + STROKE_THRESHOLD_G
    bool       isAboveThreshold() const;///< True while the FSM is in ABOVE

    /** Reset counts, interval history and classifier window; keep the baseline. */
    void reset();

    /**
     * @brief Classify a window of samples with the decision tree.
     *        Pure function, exposed so it can be unit-tested on the host.
     */
    static StrokeType classifyWindow(const float* axWindow,
                                     const float* gxWindow,
                                     uint8_t n);

private:
    enum class State : uint8_t { BELOW, ABOVE };

    void       _pushInterval(uint32_t intervalMs);
    void       _updateRate();
    StrokeType _classifyStroke();   ///< UNKNOWN until the window is full

    State      _state;
    EMAFilter  _baselineFilter;

    uint32_t   _strokeCount;
    uint32_t   _lastStrokeMs;
    StrokeType _strokeType;
    float      _rateSpm;

    uint32_t   _intervals[STROKE_RATE_WINDOW];
    uint8_t    _intervalHead;
    uint8_t    _intervalCount;

    static constexpr uint8_t CLASSIFIER_WINDOW = 50;   ///< 1 s at 50 Hz

    float   _axWindow[CLASSIFIER_WINDOW];
    float   _gxWindow[CLASSIFIER_WINDOW];
    uint8_t _classHead;
    bool    _classWindowFull;
};
