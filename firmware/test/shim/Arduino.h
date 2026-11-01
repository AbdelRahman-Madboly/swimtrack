/**
 * Minimal stand-in for the Arduino core, used only by the native test
 * environment. It provides the C library headers the detection modules rely
 * on; nothing here talks to hardware.
 */
#pragma once

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <math.h>
#include <string.h>
