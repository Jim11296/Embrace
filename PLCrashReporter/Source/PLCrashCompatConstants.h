/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2012-2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef PLCRASH_COMPAT_CONSTANTS_H
#define PLCRASH_COMPAT_CONSTANTS_H 1

#include <AvailabilityMacros.h>

#include <mach/machine.h>

enum {
    UNWIND_ARM64_MODE_MASK                  = 0x0F000000,
    UNWIND_ARM64_MODE_FRAME_OLD             = 0x01000000,
    UNWIND_ARM64_MODE_FRAMELESS             = 0x02000000,
    UNWIND_ARM64_MODE_DWARF                 = 0x03000000,
    UNWIND_ARM64_MODE_FRAME                 = 0x04000000,
    
    UNWIND_ARM64_FRAME_X19_X20_PAIR         = 0x00000001,
    UNWIND_ARM64_FRAME_X21_X22_PAIR         = 0x00000002,
    UNWIND_ARM64_FRAME_X23_X24_PAIR         = 0x00000004,
    UNWIND_ARM64_FRAME_X25_X26_PAIR         = 0x00000008,
    UNWIND_ARM64_FRAME_X27_X28_PAIR         = 0x00000010,
    
    UNWIND_ARM64_FRAMELESS_STACK_SIZE_MASK  = 0x00FFF000,
    UNWIND_ARM64_DWARF_SECTION_OFFSET       = 0x00FFFFFF,
};

#endif /* PLCRASH_COMPAT_CONSTANTS_H */
