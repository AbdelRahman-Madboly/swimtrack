# Hardware

## Wrist unit (firmware/)

| Part | Used | Notes |
|---|---|---|
| MCU | LOLIN S2 Mini (ESP32-S2) | Native USB; Serial is USB CDC |
| IMU | GY-6500 breakout (MPU-6500) | WHO_AM_I reads 0x70; AD0 to GND gives address 0x68 |
| Power | USB | A LiPo and charger board are planned, not fitted |

```
LOLIN S2 Mini            GY-6500 (MPU-6500)
-------------            ------------------
3V3     ---------------> VCC
GND     ---------------> GND
GPIO33  ---------------> SCL
GPIO34  ---------------> SDA
GND     ---------------> AD0
```

| Pin | Use |
|---|---|
| GPIO15 | On-board LED |
| GPIO0 | BOOT button: start/stop, 3 s press resets, wakes from deep sleep |
| GPIO1 | Battery ADC input. Expects a 100k/100k divider from the cell; not fitted, so the reading is 0 |

Sensor ranges: +/-8 g (4096 LSB/g) and +/-1000 dps (32.8 LSB/dps), 50 Hz.

## Capture rig (data-collection/)

| Role | Board |
|---|---|
| Sender, worn on the wrist | LOLIN S2 Mini with the same GY-6500 wiring as above |
| Receiver, on USB | ESP32 30-pin dev module (CP2102 or CH340) |

Both boards talk ESP-NOW on WiFi channel 1. The sender broadcasts unless a
receiver MAC is set in `swimtrack-sender/src/config_local.h`.

## Earlier development hardware

The first firmware bench tests ran on an ESP32 30-pin dev board with an
MPU-6050 (GY-521) on GPIO22/21 (WHO_AM_I 0x68). The current `config.h` targets
the S2 Mini and MPU-6500 only.
