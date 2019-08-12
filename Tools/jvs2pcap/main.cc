// Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "pcap_writer.h"
#include "serial_reader.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/timeb.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

int main(int argc, char** argv) {
  SerialReader reader;
  if (!reader.Open(argv[1])) {
    perror(argv[1]);
    exit(EXIT_FAILURE);
  }

  mkfifo("jvsio.fifo", 0666);
  int fd = open("jvsio.fifo", O_WRONLY);

  constexpr int snaplen = 257 + 4;
  PcapWriter writer(fd, timezone, snaplen, /*network=*/0);

  uint8_t buffer[snaplen];
  // MAGIC
  buffer[0] = 'J';
  buffer[1] = 'V';
  buffer[2] = 'S';
  buffer[3] = '@';
  uint8_t* data = &buffer[4];
  for (int offset = 0, orig_len = 0, escape = 0;;) {
    if (!reader.ReadByte(&data[offset])) {
      perror("serial read");
      exit(EXIT_FAILURE);
    }
    if (orig_len == 0 && data[offset] != 0xe0)
      continue;
    orig_len++;
    if (0xd0 == data[offset]) {
      escape = 1;
    } else if (escape) {
      data[offset]++;
      escape = 0;
      offset++;
    } else {
      offset++;
    }
    if (offset >= 3 && offset == (data[2] + 3)) {
      struct timeb tb;
      ftime(&tb);
      writer.WritePacket(
          tb.time, tb.millitm * 1000, offset + 4, orig_len + 4, buffer);
      orig_len = 0;
      offset = 0;
    }
  }
  return 0;
}

