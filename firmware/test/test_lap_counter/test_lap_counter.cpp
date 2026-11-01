// Host-side tests for the turn FSM (lap counting) and rest detection.
// Samples are fed at 50 Hz (20 ms apart).
#include <unity.h>
#include "lap_counter.h"

static const uint32_t DT = SAMPLE_PERIOD_MS;
static LapCounter laps;
static uint32_t now;
static int lapsSeen;
static int restStarts;
static int restEnds;

void setUp() {
    laps.begin();
    now = 1000;
    lapsSeen = 0;
    restStarts = 0;
    restEnds = 0;
}
void tearDown() {}

static void feed(float gyroZ, float mag, int samples,
                 uint32_t strokes = 0, float rate = 0.0f, uint8_t pool = 25) {
    for (int i = 0; i < samples; i++) {
        if (laps.update(gyroZ, mag, strokes, rate, now, pool)) lapsSeen++;
        if (laps.restJustStarted()) restStarts++;
        if (laps.restJustEnded()) restEnds++;
        now += DT;
    }
}

// Swimming with arm motion: alternating magnitude, no rotation.
static void swim(int samples, uint32_t strokes = 0) {
    for (int i = 0; i < samples; i++) feed(0.0f, (i % 2) ? 1.6f : 0.6f, 1, strokes);
}

// Wall turn: 100 ms rotation spike, then a 200 ms low-magnitude glide.
static void turn(float gyroZ = 250.0f, uint32_t strokes = 0, uint8_t pool = 25) {
    feed(gyroZ, 1.3f, 5, strokes, 30.0f, pool);
    feed(0.0f, 0.8f, 10, strokes, 30.0f, pool);
}

static void test_begin_starts_clean() {
    TEST_ASSERT_EQUAL_UINT16(0, laps.lapCount());
    TEST_ASSERT_FALSE(laps.isResting());
    TEST_ASSERT_FALSE(laps.turnPending());
}

static void test_spike_then_glide_confirms_a_lap() {
    swim(100);
    turn(250.0f, 18, 25);
    TEST_ASSERT_EQUAL_UINT16(1, laps.lapCount());
    TEST_ASSERT_EQUAL(1, lapsSeen);
    const LapRecord& lap = laps.lastLap();
    TEST_ASSERT_EQUAL_UINT16(1, lap.lap_number);
    TEST_ASSERT_EQUAL_UINT32(18, lap.stroke_count);
    TEST_ASSERT_FLOAT_WITHIN(1e-3f, 18.0f + lap.duration_s, lap.swolf);
    TEST_ASSERT_FLOAT_WITHIN(1e-3f, 25.0f / 18.0f, lap.dps_m_per_stroke);
    TEST_ASSERT_FALSE(laps.turnPending());
}

static void test_negative_rotation_also_counts() {
    swim(50);
    turn(-250.0f);
    TEST_ASSERT_EQUAL_UINT16(1, laps.lapCount());
}

static void test_short_spike_is_rejected_as_noise() {
    swim(50);
    feed(400.0f, 1.3f, 1);    // 20 ms, below TURN_SPIKE_MIN_MS
    feed(0.0f, 0.8f, 20);
    TEST_ASSERT_EQUAL_UINT16(0, laps.lapCount());
    TEST_ASSERT_FALSE(laps.turnPending());
}

static void test_spike_without_glide_expires() {
    swim(50);
    feed(250.0f, 1.3f, 5);
    TEST_ASSERT_TRUE(laps.turnPending());
    swim(TURN_GLIDE_WINDOW_MS / DT + 10);
    TEST_ASSERT_EQUAL_UINT16(0, laps.lapCount());
    TEST_ASSERT_FALSE(laps.turnPending());
}

static void test_min_lap_duration_guard() {
    swim(50);
    turn();                                   // lap 1
    TEST_ASSERT_EQUAL_UINT16(1, laps.lapCount());
    swim(5000 / DT);                          // 5 s later, too soon
    turn();
    TEST_ASSERT_EQUAL_UINT16(1, laps.lapCount());
    swim(LAP_MIN_DURATION_MS / DT);           // past the guard
    turn(250.0f, 20);
    TEST_ASSERT_EQUAL_UINT16(2, laps.lapCount());
    TEST_ASSERT_TRUE(laps.lastLap().duration_s * 1000.0f >= (float)LAP_MIN_DURATION_MS);
    TEST_ASSERT_EQUAL_UINT32(20, laps.lastLap().stroke_count);
}

static void test_zero_strokes_gives_zero_distance_per_stroke() {
    swim(50);
    turn(250.0f, 0);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 0.0f, laps.lastLap().dps_m_per_stroke);
}

static void test_still_wrist_enters_rest_then_motion_ends_it() {
    swim(100);
    TEST_ASSERT_FALSE(laps.isResting());
    feed(0.0f, 1.0f, (REST_DURATION_MS / DT) + 60);   // still for > rest duration
    TEST_ASSERT_TRUE(laps.isResting());
    TEST_ASSERT_EQUAL(1, restStarts);
    // Rest ends once the 1 s variance window holds enough motion.
    swim(VAR_WINDOW_SIZE);
    TEST_ASSERT_FALSE(laps.isResting());
    TEST_ASSERT_EQUAL(1, restEnds);
    TEST_ASSERT_TRUE(laps.lastRestDurationS() > REST_DURATION_MS / 1000.0f);
}

static void test_short_pause_is_not_rest() {
    swim(100);
    feed(0.0f, 1.0f, (REST_DURATION_MS / DT) / 2);
    swim(100);
    TEST_ASSERT_FALSE(laps.isResting());
    TEST_ASSERT_EQUAL(0, restStarts);
}

static void test_reset_clears_laps() {
    swim(50);
    turn();
    laps.reset();
    TEST_ASSERT_EQUAL_UINT16(0, laps.lapCount());
    TEST_ASSERT_EQUAL_UINT32(0, laps.lapStartMs());
}

int main(int, char**) {
    UNITY_BEGIN();
    RUN_TEST(test_begin_starts_clean);
    RUN_TEST(test_spike_then_glide_confirms_a_lap);
    RUN_TEST(test_negative_rotation_also_counts);
    RUN_TEST(test_short_spike_is_rejected_as_noise);
    RUN_TEST(test_spike_without_glide_expires);
    RUN_TEST(test_min_lap_duration_guard);
    RUN_TEST(test_zero_strokes_gives_zero_distance_per_stroke);
    RUN_TEST(test_still_wrist_enters_rest_then_motion_ends_it);
    RUN_TEST(test_short_pause_is_not_rest);
    RUN_TEST(test_reset_clears_laps);
    return UNITY_END();
}
