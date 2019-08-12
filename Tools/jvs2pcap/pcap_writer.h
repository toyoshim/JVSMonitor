// Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if !defined(__PCAP_WRITER_H__)
#define __PCAP_WRITER_H__

#include <stdint.h>

class PcapWriter {
 public:
  PcapWriter(int fd, int32_t thiszone, uint32_t snaplen, uint32_t network);

  void WritePacket(
      uint32_t ts_sec, uint32_t ts_usec, uint32_t incl_len, uint32_t orig_len,
      uint8_t* incl_data);

 private:
  int fd_;
};

#endif // !defined(__PCAL_WRITER_H__)
