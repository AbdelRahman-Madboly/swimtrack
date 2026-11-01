/**
 * @file    main.cpp
 * @brief   SwimTrack Sender: 50 Hz IMU sampling sent over ESP-NOW.
 *
 *          What it does:
 *            1. Calibration offset measurement:
 *                 - On boot, reads CALIB_SAMPLE_COUNT (150) samples while still.
 *                 - Computes mean ax, ay, az, gx, gy, gz.
 *                 - ax/ay/az offset = mean (expected: ~0 except az ≈ 1.0 g)
 *                 - az offset = mean_az - 1.0f  (removes gravity component)
 *                 - gx/gy/gz offset = mean (expected: ~0 dps)
 *                 - Offsets are subtracted from every sample from that point on.
 *                 - Offsets and a pass/fail check are printed to Serial.
 *
 *            2. ESP-NOW broadcast:
 *                 - WiFi set to STA mode (required by ESP-NOW on S2).
 *                 - ESP-NOW peer is ESPNOW_PEER_MAC: broadcast by default,
 *                   or the receiver MAC set in src/config_local.h.
 *                 - SensorPacket (37 bytes) filled and sent every 20 ms.
 *                 - Rolling seq counter (0–255) for drop detection on receiver.
 *
 *            3. LED: 2 ms flash on each successful ESP-NOW send.
 *
 *            4. Stats every 5 s (Serial):
 *                 [STATS] send=50.0Hz sent=250 ack_fail=0 heap=xxxxxx
 *
 *          Serial output (one line per sample):
 *            [ts_ms] ax=X.XXX ay=X.XXX az=X.XXX gz=X.XX mag=X.XXXX temp=XX.X
 *
 *          Calibration output (printed once at boot):
 *            [CALIB] Collecting 150 samples (keep device still)...
 *            [CALIB] ax_offset=-0.002  ay_offset= 0.001  az_offset= 0.003
 *            [CALIB] gx_offset= 0.12   gy_offset=-0.08   gz_offset= 0.05
 *            [CALIB] PASS - offsets within limits (±0.2g, ±5dps)
 *
 * @note    Keep device completely still during the first 3 seconds after boot.
 *          If you move it, the offsets will be skewed and still-label data
 *          will show non-zero drift.
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <math.h>

#include "config.h"
#include "mpu6500.h"
#include "imu_filters.h"
#include "sensor_packet.h"

// ============================================================
//  CALIBRATION LIMITS  (flag if offsets are unexpectedly large)
// ============================================================

static constexpr float CALIB_ACCEL_LIMIT_G   = 0.2f;   ///< ±0.2 g max offset
static constexpr float CALIB_GYRO_LIMIT_DPS  = 5.0f;   ///< ±5 dps max offset

// ============================================================
//  GLOBALS
// ============================================================

static MPU6500   s_imu;
static EMAFilter s_magFilter(EMA_ALPHA);
static IMUSample s_sample;

// ── Calibration offsets (applied to every sample after boot) ──
static float s_ax_off = 0.0f;
static float s_ay_off = 0.0f;
static float s_az_off = 0.0f;
static float s_gx_off = 0.0f;
static float s_gy_off = 0.0f;
static float s_gz_off = 0.0f;

// ── Sequence counter ──────────────────────────────────────────
static uint8_t  s_seq        = 0;

// ── Timing ────────────────────────────────────────────────────
static uint32_t s_nextSampleMs = 0;
static uint32_t s_statsWindowMs = 0;

// ── Statistics ────────────────────────────────────────────────
static uint32_t s_sentCount    = 0;
static uint32_t s_ackFailCount = 0;
static uint32_t s_readFailCount = 0;

// ── ESP-NOW send result (set in callback, read in loop) ───────
static volatile bool s_lastSendOk = true;

// ============================================================
//  LED HELPERS
// ============================================================

static void ledFlash(uint32_t ms)
{
    digitalWrite(PIN_LED, HIGH);
    delay(ms);
    digitalWrite(PIN_LED, LOW);
}

static void ledBlink(uint8_t count, uint32_t onMs, uint32_t offMs)
{
    for (uint8_t i = 0; i < count; i++) {
        digitalWrite(PIN_LED, HIGH); delay(onMs);
        digitalWrite(PIN_LED, LOW);  delay(offMs);
    }
}

// ============================================================
//  ESP-NOW SEND CALLBACK
// ============================================================

/**
 * @brief Called by the ESP-NOW stack after each send attempt.
 *        Runs in a WiFi task context - keep it minimal.
 *        Only sets a flag; the main loop reads it for stats.
 */
static void onDataSent(const uint8_t* /*mac_addr*/, esp_now_send_status_t status)
{
    s_lastSendOk = (status == ESP_NOW_SEND_SUCCESS);
}

// ============================================================
//  SELF-TEST
// ============================================================

static void selfTest()
{
    Serial.println();
    Serial.println("==========================================");
    Serial.println("  SwimTrack Sender (ESP-NOW)");
    Serial.println("  IMU self-test");
    Serial.println("==========================================");

    Serial.print("[SELF-TEST] IMU init ... ");
    if (s_imu.begin()) {
        Serial.printf("PASS  (WHO_AM_I=0x%02X)\n", s_imu.whoAmI());
        ledBlink(2, 300, 300);
    } else {
        Serial.println("FAIL - WHO_AM_I mismatch or I2C wiring error");
        Serial.printf(  "  Expected: 0x%02X\n", MPU_WHO_AM_I_VAL);
        Serial.printf(  "  Got     : 0x%02X\n", s_imu.whoAmI());
        Serial.println("  Check: SDA→GPIO34, SCL→GPIO33, VCC→3.3V, GND→GND");
        Serial.println("[SELF-TEST] HALTED");
        while (true) { ledFlash(80); delay(80); }
    }

    Serial.printf("[SELF-TEST] Sample rate  : %d Hz\n",   SAMPLE_RATE_HZ);
    Serial.printf("[SELF-TEST] Accel range  : ±%d g\n",   2 << ACCEL_FS_SEL);
    Serial.printf("[SELF-TEST] Gyro range   : ±%d dps\n", 250 << GYRO_FS_SEL);
    Serial.printf("[SELF-TEST] EMA alpha    : %.2f\n",     EMA_ALPHA);
    Serial.printf("[SELF-TEST] Calib samples: %d (%.1f s)\n",
                  CALIB_SAMPLE_COUNT,
                  (float)CALIB_SAMPLE_COUNT / (float)SAMPLE_RATE_HZ);
    Serial.println("[SELF-TEST] ALL PASS ✓");
    Serial.println();
}

// ============================================================
//  ESP-NOW INIT
// ============================================================

static void espnowInit()
{
    Serial.print("[ESPNOW] Initialising ... ");

    // ESP-NOW on S2 requires WiFi in STA mode
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();

    if (esp_now_init() != ESP_OK) {
        Serial.println("FAIL - esp_now_init() returned error");
        Serial.println("[ESPNOW] HALTED");
        while (true) { ledFlash(200); delay(200); }
    }

    esp_now_register_send_cb(onDataSent);

    // Add broadcast peer
    esp_now_peer_info_t peer{};
    const uint8_t peerMac[] = ESPNOW_PEER_MAC;
    memcpy(peer.peer_addr, peerMac, 6);
    peer.channel  = ESPNOW_WIFI_CHANNEL;
    peer.encrypt  = false;
    peer.ifidx    = WIFI_IF_STA;

    if (esp_now_add_peer(&peer) != ESP_OK) {
        Serial.println("FAIL - esp_now_add_peer() returned error");
        while (true) { ledFlash(200); delay(200); }
    }

    // Print our own MAC so you can note it down
    Serial.println("OK");
    Serial.printf("[ESPNOW] Sender MAC : %s\n",
                  WiFi.macAddress().c_str());
    Serial.printf("[ESPNOW] WiFi channel: %d\n", ESPNOW_WIFI_CHANNEL);
    Serial.printf("[ESPNOW] Peer MAC   : %02X:%02X:%02X:%02X:%02X:%02X\n",
                  peerMac[0], peerMac[1], peerMac[2],
                  peerMac[3], peerMac[4], peerMac[5]);
    Serial.println();
}

// ============================================================
//  CALIBRATION
// ============================================================

/**
 * @brief Collect CALIB_SAMPLE_COUNT still samples and compute axis offsets.
 *
 *        Accel offsets:
 *          ax_off = mean(ax)         (expected: ~0)
 *          ay_off = mean(ay)         (expected: ~0)
 *          az_off = mean(az) - 1.0   (expected: ~0 after removing gravity)
 *
 *        Gyro offsets:
 *          gx/gy/gz_off = mean(gx/gy/gz)  (expected: ~0)
 *
 *        Offsets are stored in file-scope variables and applied in the main loop.
 */
static void measureCalibrationOffsets()
{
    Serial.printf("[CALIB] Collecting %d samples - keep device still ...\n",
                  CALIB_SAMPLE_COUNT);

    double sum_ax = 0, sum_ay = 0, sum_az = 0;
    double sum_gx = 0, sum_gy = 0, sum_gz = 0;
    int    collected = 0;

    IMUSample s;
    uint32_t  nextMs = millis();

    while (collected < CALIB_SAMPLE_COUNT) {
        const uint32_t now = millis();
        if (now >= nextMs) {
            nextMs += SAMPLE_PERIOD_MS;
            if (s_imu.read(s)) {
                sum_ax += s.ax;
                sum_ay += s.ay;
                sum_az += s.az;
                sum_gx += s.gx;
                sum_gy += s.gy;
                sum_gz += s.gz;
                collected++;

                // Progress dot every 25 samples
                if (collected % 25 == 0) {
                    Serial.printf("[CALIB] ... %d / %d\n",
                                  collected, CALIB_SAMPLE_COUNT);
                }
            }
        }
    }

    const float n = static_cast<float>(CALIB_SAMPLE_COUNT);
    s_ax_off = static_cast<float>(sum_ax / n);
    s_ay_off = static_cast<float>(sum_ay / n);
    s_az_off = static_cast<float>(sum_az / n) - 1.0f;  // remove gravity
    s_gx_off = static_cast<float>(sum_gx / n);
    s_gy_off = static_cast<float>(sum_gy / n);
    s_gz_off = static_cast<float>(sum_gz / n);

    Serial.printf("[CALIB] ax_offset = %+.4f g\n",   s_ax_off);
    Serial.printf("[CALIB] ay_offset = %+.4f g\n",   s_ay_off);
    Serial.printf("[CALIB] az_offset = %+.4f g  (mean_az=%.4f, gravity removed)\n",
                  s_az_off, s_az_off + 1.0f);
    Serial.printf("[CALIB] gx_offset = %+.4f dps\n", s_gx_off);
    Serial.printf("[CALIB] gy_offset = %+.4f dps\n", s_gy_off);
    Serial.printf("[CALIB] gz_offset = %+.4f dps\n", s_gz_off);

    // Sanity check - large offsets indicate a loose sensor or wiring issue
    bool accelOk = (fabsf(s_ax_off) < CALIB_ACCEL_LIMIT_G  &&
                    fabsf(s_ay_off) < CALIB_ACCEL_LIMIT_G  &&
                    fabsf(s_az_off) < CALIB_ACCEL_LIMIT_G);
    bool gyroOk  = (fabsf(s_gx_off) < CALIB_GYRO_LIMIT_DPS &&
                    fabsf(s_gy_off) < CALIB_GYRO_LIMIT_DPS &&
                    fabsf(s_gz_off) < CALIB_GYRO_LIMIT_DPS);

    if (accelOk && gyroOk) {
        Serial.println("[CALIB] PASS - offsets within limits (±0.2g, ±5dps)");
    } else {
        Serial.println("[CALIB] WARNING - one or more offsets are large:");
        if (!accelOk) Serial.println("  Accel offset > 0.2g - check sensor seating");
        if (!gyroOk)  Serial.println("  Gyro offset > 5dps  - ensure device was still");
        Serial.println("  Offsets will still be applied. Check sensor mounting.");
    }
    Serial.println();

    // Seed the EMA filter with 1.0 g (expected still magnitude after offset correction)
    s_magFilter.reset(1.0f);
}

// ============================================================
//  SETUP
// ============================================================

void setup()
{
    Serial.begin(115200);
    delay(400);   // USB CDC enumerate on S2 Mini

    pinMode(PIN_LED,    OUTPUT);
    pinMode(PIN_BUTTON, INPUT_PULLUP);
    digitalWrite(PIN_LED, LOW);

    selfTest();        // IMU check - halts on failure
    espnowInit();      // WiFi STA + ESP-NOW peer - halts on failure
    measureCalibrationOffsets();   // 3-second still measurement

    const uint32_t now = millis();
    s_nextSampleMs  = now;
    s_statsWindowMs = now;

    Serial.println("--- Live data (50 Hz, ESP-NOW active) ---");
    Serial.println("[ts_ms] ax=X.XXX ay=X.XXX az=X.XXX gz=X.XX mag=X.XXXX temp=XX.X");
    Serial.println();
}

// ============================================================
//  LOOP
// ============================================================

void loop()
{
    const uint32_t now = millis();

    // ── 50 Hz sample gate ───────────────────────────────────────
    if (now >= s_nextSampleMs) {
        s_nextSampleMs += SAMPLE_PERIOD_MS;

        // Guard against large timer drift on startup
        if (now > s_nextSampleMs + SAMPLE_PERIOD_MS) {
            s_nextSampleMs = now + SAMPLE_PERIOD_MS;
        }

        if (s_imu.read(s_sample)) {

            // ── Apply calibration offsets ────────────────────────
            s_sample.ax -= s_ax_off;
            s_sample.ay -= s_ay_off;
            s_sample.az -= s_az_off;
            s_sample.gx -= s_gx_off;
            s_sample.gy -= s_gy_off;
            s_sample.gz -= s_gz_off;

            // ── Compute raw magnitude (before EMA) ───────────────
            const float mag_raw = sqrtf(s_sample.ax * s_sample.ax +
                                        s_sample.ay * s_sample.ay +
                                        s_sample.az * s_sample.az);

            // ── EMA for Serial display only ──────────────────────
            const float mag_filt = s_magFilter.update(mag_raw);

            // ── Fill SensorPacket ─────────────────────────────────
            SensorPacket pkt;
            pkt.ts_ms   = s_sample.timestamp;
            pkt.ax      = s_sample.ax;
            pkt.ay      = s_sample.ay;
            pkt.az      = s_sample.az;
            pkt.gx      = s_sample.gx;
            pkt.gy      = s_sample.gy;
            pkt.gz      = s_sample.gz;
            pkt.temp_c  = s_sample.temp_c;
            pkt.mag_raw = mag_raw;
            pkt.seq     = s_seq++;

            // ── Send via ESP-NOW ──────────────────────────────────
            const uint8_t peerMac[] = ESPNOW_PEER_MAC;
            esp_err_t err = esp_now_send(peerMac,
                                         reinterpret_cast<const uint8_t*>(&pkt),
                                         sizeof(pkt));

            if (err == ESP_OK) {
                s_sentCount++;
                // Brief LED flash - visible sign the loop is running
                ledFlash(ESPNOW_SEND_LED_MS);
            } else {
                s_ackFailCount++;
                DBG("ESPNOW", "send error: %d", (int)err);
            }

            // ── Serial print  ────────────
            Serial.printf(
                "[%lu] ax=%6.3f ay=%6.3f az=%6.3f "
                "gz=%7.2f mag=%6.4f temp=%5.1f seq=%u\n",
                (unsigned long)s_sample.timestamp,
                s_sample.ax, s_sample.ay, s_sample.az,
                s_sample.gz,
                mag_filt,
                s_sample.temp_c,
                (unsigned)pkt.seq);

        } else {
            s_readFailCount++;
            DBG("MAIN", "WARNING: imu.read() failed (total: %lu)",
                (unsigned long)s_readFailCount);
        }
    }

    // ── Stats every 5 s ──────────────────────────────────────────
    if (now - s_statsWindowMs >= STATS_INTERVAL_MS) {
        const float elapsed = (float)(now - s_statsWindowMs) / 1000.0f;
        const float hz      = (float)s_sentCount / elapsed;

        Serial.printf(
            "[STATS] send=%.1f Hz | sent=%lu | ack_fail=%lu | "
            "read_fail=%lu | heap=%u bytes\n",
            hz,
            (unsigned long)s_sentCount,
            (unsigned long)s_ackFailCount,
            (unsigned long)s_readFailCount,
            (unsigned)ESP.getFreeHeap());

        s_sentCount     = 0;
        s_ackFailCount  = 0;
        s_readFailCount = 0;
        s_statsWindowMs = now;
    }
}
