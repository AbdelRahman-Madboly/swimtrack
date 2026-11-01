// Host-side tests for the stroke detection FSM, stroke rate and the
// stroke-style decision tree. Samples are fed at 50 Hz (20 ms apart).
#include <unity.h>
#include "stroke_detector.h"

static const uint32_t DT = SAMPLE_PERIOD_MS;
static StrokeDetector det;
static uint32_t now;
static uint32_t strokesSeen;

void setUp() {
    det.begin();
    now = 1000;
    strokesSeen = 0;
}
void tearDown() {}

static void feed(float mag, int samples, float ax = 0.0f, float gx = 0.0f) {
    for (int i = 0; i < samples; i++) {
        if (det.update(mag, ax, gx, now)) strokesSeen++;
        now += DT;
    }
}

// One arm cycle: 5 samples (100 ms) well above threshold, then quiet.
static void stroke(int quietSamples, float ax = 0.0f, float gx = 0.0f) {
    feed(1.6f, 5, ax, gx);
    feed(1.0f, quietSamples, ax, gx);
}

static void test_begin_seeds_baseline_and_threshold() {
    TEST_ASSERT_EQUAL_UINT32(0, det.strokeCount());
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 1.0f, det.baseline());
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 1.0f + STROKE_THRESHOLD_G, det.threshold());
    TEST_ASSERT_FALSE(det.isAboveThreshold());
}

static void test_quiet_signal_counts_nothing() {
    feed(1.0f, 500);
    TEST_ASSERT_EQUAL_UINT32(0, det.strokeCount());
    TEST_ASSERT_EQUAL_UINT32(0, strokesSeen);
}

static void test_stroke_is_counted_on_falling_edge() {
    feed(1.6f, 3);
    TEST_ASSERT_TRUE(det.isAboveThreshold());
    TEST_ASSERT_EQUAL_UINT32(0, det.strokeCount());
    feed(1.0f, 1);
    TEST_ASSERT_FALSE(det.isAboveThreshold());
    TEST_ASSERT_EQUAL_UINT32(1, det.strokeCount());
    TEST_ASSERT_EQUAL_UINT32(1, strokesSeen);
}

static void test_min_gap_suppresses_double_count() {
    stroke(5);                // stroke 1, then 100 ms quiet
    stroke(45);               // second peak inside STROKE_MIN_GAP_MS
    TEST_ASSERT_EQUAL_UINT32(1, det.strokeCount());
    stroke(45);               // well past the gap
    TEST_ASSERT_EQUAL_UINT32(2, det.strokeCount());
}

static void test_ten_strokes_at_one_hertz_give_sixty_spm() {
    for (int i = 0; i < 10; i++) stroke(45);   // 50 samples = 1000 ms per cycle
    TEST_ASSERT_EQUAL_UINT32(10, det.strokeCount());
    TEST_ASSERT_FLOAT_WITHIN(0.5f, 60.0f, det.strokeRateSpm());
}

static void test_rate_is_zero_after_one_stroke() {
    stroke(45);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 0.0f, det.strokeRateSpm());
}

static void test_reset_clears_counts_and_keeps_baseline() {
    for (int i = 0; i < 3; i++) stroke(45);
    const float before = det.baseline();
    det.reset();
    TEST_ASSERT_EQUAL_UINT32(0, det.strokeCount());
    TEST_ASSERT_EQUAL_UINT32(0, det.lastStrokeTime());
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, before, det.baseline());
    TEST_ASSERT_EQUAL(StrokeType::UNKNOWN, det.strokeType());
}

static void test_stroke_type_unknown_until_window_full() {
    stroke(5);   // only 10 samples seen
    TEST_ASSERT_EQUAL_UINT32(1, det.strokeCount());
    TEST_ASSERT_EQUAL(StrokeType::UNKNOWN, det.strokeType());
}

static void test_stroke_type_after_full_window() {
    feed(1.0f, 60, -0.6f, 100.0f);
    stroke(45, -0.6f, 100.0f);
    TEST_ASSERT_EQUAL(StrokeType::BACKSTROKE, det.strokeType());

    det.begin();
    feed(1.0f, 60, -0.1f, 200.0f);
    stroke(45, -0.1f, 200.0f);
    TEST_ASSERT_EQUAL(StrokeType::FREESTYLE, det.strokeType());
}

static void test_classify_window_branches() {
    float ax[4] = {0.1f, -0.2f, 0.0f, 0.3f};
    float gx[4] = {10.0f, 300.0f, 50.0f, 0.0f};
    TEST_ASSERT_EQUAL(StrokeType::FREESTYLE, StrokeDetector::classifyWindow(ax, gx, 4));

    gx[2] = 600.0f;   // gx_max above split
    TEST_ASSERT_EQUAL(StrokeType::BACKSTROKE, StrokeDetector::classifyWindow(ax, gx, 4));

    gx[2] = 50.0f;
    ax[3] = -0.35f;   // boundary is inclusive
    TEST_ASSERT_EQUAL(StrokeType::BACKSTROKE, StrokeDetector::classifyWindow(ax, gx, 4));

    TEST_ASSERT_EQUAL(StrokeType::UNKNOWN, StrokeDetector::classifyWindow(ax, gx, 0));
}

static void test_stroke_type_names() {
    TEST_ASSERT_EQUAL_STRING("FREESTYLE", strokeTypeName(StrokeType::FREESTYLE));
    TEST_ASSERT_EQUAL_STRING("BACKSTROKE", strokeTypeName(StrokeType::BACKSTROKE));
    TEST_ASSERT_EQUAL_STRING("UNKNOWN", strokeTypeName(StrokeType::UNKNOWN));
}

int main(int, char**) {
    UNITY_BEGIN();
    RUN_TEST(test_begin_seeds_baseline_and_threshold);
    RUN_TEST(test_quiet_signal_counts_nothing);
    RUN_TEST(test_stroke_is_counted_on_falling_edge);
    RUN_TEST(test_min_gap_suppresses_double_count);
    RUN_TEST(test_ten_strokes_at_one_hertz_give_sixty_spm);
    RUN_TEST(test_rate_is_zero_after_one_stroke);
    RUN_TEST(test_reset_clears_counts_and_keeps_baseline);
    RUN_TEST(test_stroke_type_unknown_until_window_full);
    RUN_TEST(test_stroke_type_after_full_window);
    RUN_TEST(test_classify_window_branches);
    RUN_TEST(test_stroke_type_names);
    return UNITY_END();
}
