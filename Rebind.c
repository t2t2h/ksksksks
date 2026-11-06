// Minimal symbol-pointer rebinding (fishhook-style) for arm64 iOS.
#include "Rebind.h"
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach/mach.h>
#include <string.h>
#include <stdint.h>

static mb_rebinding *g_rb = NULL;
static size_t g_rbn = 0;

static void patch_section(const struct section_64 *sect, intptr_t slide,
                          const struct nlist_64 *symtab, const char *strtab,
                          const uint32_t *indirect, int isConst)
{
    const uint32_t *isyms = indirect + sect->reserved1;
    void **slots = (void **)(uintptr_t)(sect->addr + slide);
    size_t count = sect->size / sizeof(void *);
    int unprotected = 0;

    for (size_t i = 0; i < count; i++) {
        uint32_t idx = isyms[i];
        if (idx == INDIRECT_SYMBOL_ABS || idx == INDIRECT_SYMBOL_LOCAL ||
            idx == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) continue;
        const char *name = strtab + symtab[idx].n_un.n_strx;
        if (name[0] != '_') continue;
        name++;
        for (size_t k = 0; k < g_rbn; k++) {
            if (strcmp(name, g_rb[k].name) == 0 && slots[i] != g_rb[k].replacement) {
                if (isConst && !unprotected) {
                    kern_return_t kr = vm_protect(mach_task_self(), (vm_address_t)slots, sect->size, 0,
                                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                    if (kr != KERN_SUCCESS) return; // can't make it writable: skip safely instead of crashing
                    unprotected = 1;
                }
                slots[i] = g_rb[k].replacement;
            }
        }
    }
}

static void on_image(const struct mach_header *mh, intptr_t slide)
{
    if (!mh || mh->magic != MH_MAGIC_64) return;
    const struct mach_header_64 *h = (const struct mach_header_64 *)mh;

    const struct symtab_command *st = NULL;
    const struct dysymtab_command *dst = NULL;
    const struct segment_command_64 *le = NULL;

    const uint8_t *p = (const uint8_t *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)p;
            if (strcmp(seg->segname, SEG_LINKEDIT) == 0) le = seg;
        } else if (lc->cmd == LC_SYMTAB) {
            st = (const struct symtab_command *)p;
        } else if (lc->cmd == LC_DYSYMTAB) {
            dst = (const struct dysymtab_command *)p;
        }
        p += lc->cmdsize;
    }
    if (!st || !dst || !le || dst->nindirectsyms == 0) return;

    uintptr_t base = (uintptr_t)slide + le->vmaddr - le->fileoff;
    const struct nlist_64 *symtab = (const struct nlist_64 *)(base + st->symoff);
    const char *strtab = (const char *)(base + st->stroff);
    const uint32_t *indirect = (const uint32_t *)(base + dst->indirectsymoff);

    p = (const uint8_t *)(h + 1);
    for (uint32_t i = 0; i < h->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)p;
            int isData = strcmp(seg->segname, "__DATA") == 0;
            int isConst = strcmp(seg->segname, "__DATA_CONST") == 0;
            if (isData || isConst) {
                const struct section_64 *secs = (const struct section_64 *)(seg + 1);
                for (uint32_t j = 0; j < seg->nsects; j++) {
                    uint32_t type = secs[j].flags & SECTION_TYPE;
                    if (type == S_LAZY_SYMBOL_POINTERS || type == S_NON_LAZY_SYMBOL_POINTERS)
                        patch_section(&secs[j], slide, symtab, strtab, indirect, isConst);
                }
            }
        }
        p += lc->cmdsize;
    }
}

void mb_rebind_init(mb_rebinding *rb, size_t n)
{
    g_rb = rb;
    g_rbn = n;
    _dyld_register_func_for_add_image(on_image); // also fires for already-loaded images
}
