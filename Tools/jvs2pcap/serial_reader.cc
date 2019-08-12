// Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "serial_reader.h"

#include <fcntl.h>
#include <memory.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>

bool SerialReader::Open(const char* path) {
  fd_ = open(path, O_RDONLY | O_NOCTTY);
  if (fd_ < 0)
    return false;
  struct termios ts;
  memset(&ts, 0, sizeof(ts));
  cfmakeraw(&ts);
  tcsetattr(fd_, TCSANOW, &ts);
  return true;
}

bool SerialReader::ReadByte(uint8_t* data) {
  int read_size = read(fd_, data, 1);
  return read_size == 1;
}
