// Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if !defined(__SERIAL_READER_H__)
#define __SERIAL_READER_H__

#include <stdint.h>

class SerialReader {
 public:
  bool Open(const char* path);
  bool ReadByte(uint8_t* data);

 private:
  int fd_;
};

#endif // !defined(__SERIAL_READER_H__)
