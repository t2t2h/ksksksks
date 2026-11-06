#pragma once
#include <stddef.h>

typedef struct {
    const char *name;      // symbol name without leading underscore
    void *replacement;
} mb_rebinding;

// Rebinds the symbols in every loaded image (and in images loaded later).
// No jailbreak / Substrate needed.
void mb_rebind_init(mb_rebinding *rebindings, size_t count);
