/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
 *
 * This Library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ACSI2STM_H
#define ACSI2STM_H

#include <Arduino.h>

// acsi2stm global configuration

#define ACSI2STM_VERSION "2.3b"

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// Number of bytes per DMA transfer to dump in verbose mode
// Set to 0 to disable data dump
#define ACSI_DUMP_LEN 26

// Serial port and speed used for debug/verbose output.
#define ACSI_SERIAL Serial
#define ACSI_SERIAL_SPEED 115200

// Set to 1 to make all SD cards readonly (returns an error if writing)
// Set to 2 to ignore writes silently (returns OK but does not actually write)
#define ACSI_READONLY 0

// Number of SD cards (1 to 5)
#define ACSI_SD_CARDS 5

// Set this to limit SD capacity artificially.
//#define ACSI_MAX_BLOCKS 0x0FFFFF // 512MB limit

// Maximum SD card speed in MHz.
// This does not set the speed, it selects speeds from a list.
// The driver automatically downgrades to a slower speed on each retry.
#define ACSI_SD_MAX_SPEED 50

// Data buffer size in 512 bytes blocks
#define ACSI_BLOCKS 8

// Device ID of the first SD card on the ACSI bus
#define ACSI_FIRST_ID 0

// Filter/delay data acquisition on ACK pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Only impacts DMA writes (ST -> STM32)
#define ACSI_ACK_FILTER 1

// Filter/delay data acquisition on CS pulse.
// Set this to 1 to sample 13.8ns later
// Set this to 2 to sample 41.6ns later
// Set this to 3 to sample 97.1ns later
// Only impacts command send (ST -> STM32)
#define ACSI_CS_FILTER 1

// Push data faster in DMA reads (STM32 -> ST)
// Setting to 1 unrolls the DMA transfer code but may be less compatible
// with some ST DMA controllers.
#define ACSI_FAST_DMA 0

// Activity LED pin. Leave undefined to remove activity LED.
#define ACSI_ACTIVITY_LED LED_BUILTIN

// Maximum number of LUNs. For driver supporting multiple LUNs, this allows
// multiple images on the same SD card.
#define ACSI_MAX_LUNS 2

// Folder containing disk images
// It must end with a "/"
#define ACSI_IMAGE_FOLDER "/acsi2stm/"

// File folder name and extension of LUN images
// The LUN number is inserted between the prefix and extension.
// Example:
//   ACSI_IMAGE_FOLDER "/acsi2stm/"
//   ACSI_LUN_IMAGE_PREFIX "hd"
//   ACSI_LUN_IMAGE_EXT ".img"
//   The image file for LUN 0 will be "/acsi2stm/hd0.img"
//   The image file for LUN 1 will be "/acsi2stm/hd1.img"
#define ACSI_LUN_IMAGE_PREFIX "hd"
#define ACSI_LUN_IMAGE_EXT ".img"

// ACSI protocol block size
#define ACSI_BLOCKSIZE 512

// vim: ts=2 sw=2 sts=2 et
#endif