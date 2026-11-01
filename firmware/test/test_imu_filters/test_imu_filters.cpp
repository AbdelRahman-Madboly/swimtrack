// Host-side tests for the EMA filter and magnitude helpers.
#include <unity.h>
#include "imu_filters.h"

void setUp() {}
void tearDown() {}

static void test_magnitude_of_unit_and_pythagorean_vectors() {
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 1.0f, accelMagnitude(0.0f, 0.0f, 1.0f));
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 5.0f, accelMagnitude(3.0f, 4.0f, 0.0f));
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 0.0f, accelMagnitude(0.0f, 0.0f, 0.0f));
}

static void test_first_sample_seeds_the_filter() {
    EMAFilter f(0.3f);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 2.0f, f.update(2.0f));
}

static void test_second_sample_is_weighted_by_alpha() {
    EMAFilter f(0.3f);
    f.update(1.0f);
    // 0.3 * 2.0 + 0.7 * 1.0 = 1.3
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 1.3f, f.update(2.0f));
}

static void test_filter_converges_to_constant_input() {
    EMAFilter f(0.3f);
    f.update(0.0f);
    for (int i = 0; i < 100; i++) f.update(1.0f);
    TEST_ASSERT_FLOAT_WITHIN(1e-4f, 1.0f, f.value());
}

static void test_alpha_is_clamped() {
    EMAFilter low(-1.0f);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 0.01f, low.alpha());
    EMAFilter high(5.0f);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 1.0f, high.alpha());
}

static void test_reset_with_seed_keeps_value() {
    EMAFilter f(0.5f);
    f.reset(1.0f);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 1.0f, f.value());
    // Seeded, so the next sample is blended, not copied.
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 2.0f, f.update(3.0f));
}

static void test_filtered_magnitude_wrapper() {
    EMAFilter f(0.3f);
    TEST_ASSERT_FLOAT_WITHIN(1e-6f, 5.0f, filteredMagnitude(f, 3.0f, 4.0f, 0.0f));
}

int main(int, char**) {
    UNITY_BEGIN();
    RUN_TEST(test_magnitude_of_unit_and_pythagorean_vectors);
    RUN_TEST(test_first_sample_seeds_the_filter);
    RUN_TEST(test_second_sample_is_weighted_by_alpha);
    RUN_TEST(test_filter_converges_to_constant_input);
    RUN_TEST(test_alpha_is_clamped);
    RUN_TEST(test_reset_with_seed_keeps_value);
    RUN_TEST(test_filtered_magnitude_wrapper);
    return UNITY_END();
}
