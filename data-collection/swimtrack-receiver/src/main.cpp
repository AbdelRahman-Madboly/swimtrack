/**
 * @file    main.cpp
 * @brief   SwimTrack Receiver: ESP-NOW packets to Serial CSV.
 *
 *          This project runs on an ESP32 30-pin dev module connected via USB
 *          to the laptop. It receives SensorPacket structs broadcast by the
 *          LOLIN S2 Mini sender and prints one CSV line per packet to Serial.
 *          The laptop's collect.py reads this stream.
 *
 *          Boot sequence:
 *            1. Serial.begin(115200)
 *            2. Print receiver MAC address  (optional, for unicast)
 *            3. ESP-NOW init in receive-only mode
 *            4. Print CSV header once
 *            5. Wait for packets (all work happens in the recv callback)
 *
 *          CSV line format (one per received packet):
 *            ts_ms,ax,ay,az,gx,gy,gz,temp_c,mag_raw,seq,dropped
 *
 *          Non-CSV output always starts with '[' so collect.py can skip it:
 *            [INFO] ...
 *            [ESPNOW] ...
 *            [STATS] ...
 *
 *          Drop detection:
 *            dropped=1 if received seq != (last_seq + 1) % 256
 *            First packet is never flagged as dropped regardless of seq value.
 *
 * @note    The sender broadcasts by default. To unicast instead, put the MAC
 *          printed on boot into swimtrack-sender/src/config_local.h as
 *          ESPNOW_PEER_MAC.
 *          Then reflash the sender to enable unicast (ACK-based) delivery.
 *
 * @author  SwimTrack Firmware Team
 * @date    2026-04
 */

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>

#include "sensor_packet.h"

// ============================================================
//  CONSTANTS
// ============================================================

static constexpr uint32_t STATS_INTERVAL_MS = 5000UL;  ///< Stats print period

// ============================================================
//  GLOBALS
// ============================================================

// ── Drop detection ────────────────────────────────────────────
static volatile uint8_t  s_lastSeq        = 0;
static volatile bool     s_firstPacket    = true;

// ── Statistics (updated in callback, read in loop) ───────────
static volatile uint32_t s_totalReceived  = 0;
static volatile uint32_t s_totalDropped  = 0;

// ── Timing (main loop only) ───────────────────────────────────
static uint32_t s_statsWindowMs  = 0;
static uint32_t s_windowReceived = 0;   ///< count in current 5 s window

// ============================================================
//  ESP-NOW RECEIVE CALLBACK
// ============================================================

/**
 * @brief Called by the ESP-NOW stack for every received packet.
 *        Runs in the WiFi task context - MUST be fast, no heap alloc,
 *        no Serial.print blocking (Serial.printf is safe here on ESP32).
 *
 *        Casts the raw bytes to SensorPacket, checks seq for drops,
 *        and immediately prints one CSV line to Serial.
 */
static void onDataRecv(const uint8_t* /*mac_addr*/,
                       const uint8_t* data,
                       int            len)
{
    // Sanity-check payload length before casting
    if (len != static_cast<int>(sizeof(SensorPacket))) {
        Serial.printf("[WARN] Unexpected packet length: %d (expected %d)\n",
                      len, (int)sizeof(SensorPacket));
        return;
    }

    // Cast - safe because sender uses the same packed struct
    const SensorPacket* pkt = reinterpret_cast<const SensorPacket*>(data);

    // ── Drop detection ──────────────────────────────────────────
    uint8_t dropped = 0;

    if (s_firstPacket) {
        // First packet ever: seed last_seq, never flag as dropped
        s_lastSeq     = pkt->seq;
        s_firstPacket = false;
    } else {
        const uint8_t expected = static_cast<uint8_t>((s_lastSeq + 1u) % 256u);
        if (pkt->seq != expected) {
            dropped = 1;
            s_totalDropped++;
        }
        s_lastSeq = pkt->seq;
    }

    s_totalReceived++;
    s_windowReceived++;

    // ── CSV line - one per packet, flushed immediately ──────────
    // collect.py skips any line that does NOT start with a digit.
    // Format: ts_ms,ax,ay,az,gx,gy,gz,temp_c,mag_raw,seq,dropped
    Serial.printf(
        "%u,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.4f,%u,%u\n",
        pkt->ts_ms,
        pkt->ax, pkt->ay, pkt->az,
        pkt->gx, pkt->gy, pkt->gz,
        pkt->temp_c,
        pkt->mag_raw,
        static_cast<unsigned>(pkt->seq),
        static_cast<unsigned>(dropped));

    // Flush ensures collect.py gets each line without buffering delay
    Serial.flush();
}

// ============================================================
//  SETUP
// ============================================================

void setup()
{
    Serial.begin(115200);
    delay(500);   // Let USB-Serial enumerate on host side

    Serial.println();
    Serial.println("==========================================");
    Serial.println("  SwimTrack Receiver");
    Serial.println("==========================================");

    // ── Print own MAC (user needs this to configure sender) ────
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    Serial.printf("[INFO] Receiver MAC: %s\n", WiFi.macAddress().c_str());
    Serial.println("[INFO] Optional: set it as ESPNOW_PEER_MAC in the sender's config_local.h");
    Serial.println("[INFO]   Then reflash the sender.");
    Serial.println();

    // ── ESP-NOW init ────────────────────────────────────────────
    Serial.print("[ESPNOW] Initialising ... ");
    if (esp_now_init() != ESP_OK) {
        Serial.println("FAIL - esp_now_init() returned error. Check board/framework.");
        while (true) { delay(1000); }
    }
    Serial.println("OK");

    esp_now_register_recv_cb(onDataRecv);

    Serial.println("[INFO] Waiting for packets...");
    Serial.println();

    // ── CSV header ─────────────────────────────────────────────
    // collect.py skips this line (starts with 't', not a digit).
    // Print it anyway so the file has a header if opened in Excel.
    Serial.println("ts_ms,ax,ay,az,gx,gy,gz,temp_c,mag_raw,seq,dropped");

    s_statsWindowMs  = millis();
    s_windowReceived = 0;
}

// ============================================================
//  LOOP
// ============================================================

void loop()
{
    const uint32_t now = millis();

    // ── Stats every 5 s ────────────────────────────────────────
    if (now - s_statsWindowMs >= STATS_INTERVAL_MS) {
        const float elapsed = static_cast<float>(now - s_statsWindowMs) / 1000.0f;
        const float hz      = static_cast<float>(s_windowReceived) / elapsed;

        Serial.printf(
            "[STATS] recv=%.1f Hz | total=%lu | dropped=%lu | heap=%u bytes\n",
            hz,
            static_cast<unsigned long>(s_totalReceived),
            static_cast<unsigned long>(s_totalDropped),
            static_cast<unsigned>(ESP.getFreeHeap()));

        s_windowReceived = 0;
        s_statsWindowMs  = now;
    }

    // Nothing else - all packet work is done in onDataRecv()
    delay(10);
}