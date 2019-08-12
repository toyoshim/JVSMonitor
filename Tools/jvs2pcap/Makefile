# Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CXX = clang++

all: jvsdump

jvsdump: main.cc serial_reader.cc pcap_writer.cc
	$(CXX) -o $@ $^
