/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2022 by Jean-Matthieu Coulon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef FLASH_FIRMWARE_H
#define FLASH_FIRMWARE_H

#include <Arduino.h>

// Crude way of determining flash size at compile time
#if defined(MCU_STM32F103CB)
static const uint32_t FLASH_SIZE = 0x20000;
#else
static const uint32_t FLASH_SIZE = 0x10000;
#endif

// Flashes firmware from the DMA port.
// Never returns.
void flashFirmware(uint32_t size);

#endif
// vim: ts=2 sw=2 sts=2 et
