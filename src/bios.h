#ifndef GBA_BIOS_H
#define GBA_BIOS_H

#include "common.h"

struct bios_div_result {
    int32_t div;
    int32_t mod;
};

THUMB EWRAM_CODE struct bios_div_result bios_div(int32_t numerator, int32_t denominator);
THUMB EWRAM_CODE void bios_halt();

#endif // GBA_BIOS_H