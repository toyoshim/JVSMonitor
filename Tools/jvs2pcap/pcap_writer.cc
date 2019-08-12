// Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "pcap_writer.h"

#include <unistd.h>

namespace {

struct PcapHeader {
  uint32_t magic_number = 0xa1b2c3d4;
  uint16_t version_major = 2;
  uint16_t version_minor = 4;
  int32_t thiszone = 0;
  uint32_t sigfigs = 0;
  uint32_t snaplen = 65535;
  uint32_t network = 0;
};

struct PcapRecordHeader {
  uint32_t ts_sec;
  uint32_t ts_usec;
  uint32_t incl_len;
  uint32_t orig_len;
};

}  // namespace


PcapWriter::PcapWriter(
    int fd, int32_t thiszone, uint32_t snaplen, uint32_t network) : fd_(fd) {
  PcapHeader header;
  header.thiszone = thiszone;
  header.snaplen = snaplen;
  header.network = network;
  write(fd, &header, sizeof(header));
}

void PcapWriter::WritePacket(
      uint32_t ts_sec, uint32_t ts_usec, uint32_t incl_len, uint32_t orig_len,
      uint8_t* incl_data) {
  PcapRecordHeader header;
  header.ts_sec = ts_sec;
  header.ts_usec = ts_usec;
  header.incl_len = incl_len;
  header.orig_len = orig_len;
  write(fd_, &header, sizeof(header));
  write(fd_, incl_data, incl_len);
}


