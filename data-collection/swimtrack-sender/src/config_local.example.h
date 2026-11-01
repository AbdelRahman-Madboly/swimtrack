/**
 * @file    config_local.example.h
 * @brief   Template for per-device sender settings that must not be committed.
 *
 *          Copy to src/config_local.h (git-ignored) and set the MAC address the
 *          receiver prints on boot ("[ESPNOW] Receiver MAC: ..."). Without this
 *          file the sender uses the broadcast address.
 */
#pragma once

#define ESPNOW_PEER_MAC  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }
