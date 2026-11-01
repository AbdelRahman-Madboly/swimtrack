/**
 * @file    stroke_detector_part2.cpp
 * @brief   StrokeDetector: accessors, reset(), interval buffer, stroke rate
 *          and the stroke-style decision tree.
 */

#include "stroke_detector.h"

// ============================================================
//  ACCESSORS
// ============================================================

/** @return Cumulative stroke count. */
uint32_t StrokeDetector::strokeCount() const  { return _strokeCount; }

/** @return Smoothed stroke rate [spm]; 0 until two strokes recorded. */
float StrokeDetector::strokeRateSpm() const   { return _rateSpm; }

/** @return millis() timestamp of most recent stroke (0 if none). */
uint32_t StrokeDetector::lastStrokeTime() const { return _lastStrokeMs; }

/** @return StrokeType of most recent stroke. */
StrokeType StrokeDetector::strokeType() const { return _strokeType; }

/** @return Current baseline estimate [g]. */
float StrokeDetector::baseline() const        { return _baselineFilter.value(); }

/**
 * @brief Dynamic detection threshold = baseline + STROKE_THRESHOLD_G.
 * @return float  Threshold [g].
 */
float StrokeDetector::threshold() const
{
    return _baselineFilter.value() + STROKE_THRESHOLD_G;
}

/** @return true while FSM is in ABOVE state (filtMag > threshold). */
bool StrokeDetector::isAboveThreshold() const
{
    return (_state == State::ABOVE);
}

// ============================================================
//  reset()
// ============================================================

/**
 * @brief Reset stroke count and interval history; preserve baseline filter.
 *
 *        The baseline retains its current state so the threshold stays
 *        calibrated immediately - no warm-up period required after reset.
 *        FSM returns to BELOW to prevent a phantom stroke on the next tick.
 *        Classifier window buffers are also cleared.
 */
void StrokeDetector::reset()
{
    _state         = State::BELOW;
    _strokeCount   = 0;
    _lastStrokeMs  = 0;
    _strokeType    = StrokeType::UNKNOWN;
    _rateSpm       = 0.0f;
    _intervalHead  = 0;
    _intervalCount = 0;
    memset(_intervals, 0, sizeof(_intervals));

    // Reset classifier window
    _classHead       = 0;
    _classWindowFull = false;
    memset(_axWindow, 0, sizeof(_axWindow));
    memset(_gxWindow, 0, sizeof(_gxWindow));

    // NOTE: _baselineFilter is intentionally NOT reset here.
    DBG("STROKE", "reset() - count=0, history cleared, classifier window cleared, "
                  "baseline retained (%.3f g)", _baselineFilter.value());
}

// ============================================================
//  PRIVATE - _pushInterval()
// ============================================================

/**
 * @brief Insert one inter-stroke interval into the circular buffer.
 *
 * @param intervalMs  Milliseconds between the two most recent strokes.
 */
void StrokeDetector::_pushInterval(uint32_t intervalMs)
{
    _intervals[_intervalHead] = intervalMs;
    _intervalHead = (_intervalHead + 1) % STROKE_RATE_WINDOW;
    if (_intervalCount < STROKE_RATE_WINDOW) {
        _intervalCount++;
    }
}

// ============================================================
//  PRIVATE - _updateRate()
// ============================================================

/**
 * @brief Recalculate _rateSpm from the current interval buffer contents.
 *
 *        Sums with integer arithmetic to avoid float accumulation error,
 *        then converts once at the end.  Returns 0 if no intervals yet.
 */
void StrokeDetector::_updateRate()
{
    if (_intervalCount == 0) {
        _rateSpm = 0.0f;
        return;
    }

    uint32_t sum = 0;
    for (uint8_t i = 0; i < _intervalCount; i++) {
        sum += _intervals[i];
    }

    const float avgMs = static_cast<float>(sum) / static_cast<float>(_intervalCount);
    _rateSpm = (avgMs > 0.0f) ? (60000.0f / avgMs) : 0.0f;
}

// ============================================================
//  Stroke-style classifier
// ============================================================

/**
 * @brief Depth-2 decision tree over a window of samples.
 *
 *        Features: ax_min (minimum accelerometer X, g) and gx_max (maximum
 *        gyroscope X, dps). The split values were fitted on one dry-land
 *        session with only freestyle and backstroke labels. They have not been
 *        validated in water.
 *
 * @return BACKSTROKE or FREESTYLE; UNKNOWN when n == 0.
 */
StrokeType StrokeDetector::classifyWindow(const float* axWindow,
                                          const float* gxWindow,
                                          uint8_t n)
{
    if (n == 0 || axWindow == nullptr || gxWindow == nullptr) {
        return StrokeType::UNKNOWN;
    }

    float ax_min = axWindow[0];
    float gx_max = gxWindow[0];
    for (uint8_t i = 1; i < n; i++) {
        if (axWindow[i] < ax_min) ax_min = axWindow[i];
        if (gxWindow[i] > gx_max) gx_max = gxWindow[i];
    }

    DBG("STROKE", "Classifier: ax_min=%.3f gx_max=%.1f", ax_min, gx_max);

    if (ax_min <= CLASSIFIER_AX_MIN_SPLIT_G)   return StrokeType::BACKSTROKE;
    if (gx_max <= CLASSIFIER_GX_MAX_SPLIT_DPS) return StrokeType::FREESTYLE;
    return StrokeType::BACKSTROKE;
}

/** @return Classification of the current window, UNKNOWN until it is full. */
StrokeType StrokeDetector::_classifyStroke()
{
    if (!_classWindowFull) {
        return StrokeType::UNKNOWN;
    }
    return classifyWindow(_axWindow, _gxWindow, CLASSIFIER_WINDOW);
}
