-- Copyright 2019 Takashi Toyoshima <toyoshim@gmail.com>. All rights reserved.
-- Use of this source code is governed by a BSD-style license that can be
-- found in the LICENSE file.

-- jvsio protocol parser for wireshark

local jvsio_proto = Proto("JVSIO", "Jamma Video Standard I/O")

-- Fields definitions
jvsio_proto.fields.address = ProtoField.uint8("jvs.addr", "Address", base.DEC)
jvsio_proto.fields.bit = ProtoField.uint8("jvs.bit", "Bit", base.DEC)
jvsio_proto.fields.bitp = ProtoField.uint8("jvs.bip", "Bit Place", base.DEC)
jvsio_proto.fields.button = ProtoField.uint8("jvs.button", "Button", base.DEC)
jvsio_proto.fields.byte = ProtoField.uint8("jvs.byte", "Length", base.DEC)
jvsio_proto.fields.bytep = ProtoField.uint8("jvs.byp", " Byte Place", base.DEC)
jvsio_proto.fields.channel = ProtoField.uint8("jvs.chan", "Channel", base.DEC)
jvsio_proto.fields.chr = ProtoField.uint8("jvs.chr", "Character", base.DEC)
jvsio_proto.fields.code = ProtoField.uint8("jvs.code", "Code", base.HEX)
jvsio_proto.fields.coin = ProtoField.uint16("jvs.coin", "Coin", base.DEC)
jvsio_proto.fields.command = ProtoField.uint8("jvs.cmd", "Command", base.HEX)
jvsio_proto.fields.condition = ProtoField.string("jvs.condition", "Condition")
jvsio_proto.fields.data = ProtoField.uint8("jvs.data", "Data", base.HEX)
jvsio_proto.fields.guard = ProtoField.uint8("jvs.guard", "Guard", base.HEX)
jvsio_proto.fields.hnum = ProtoField.uint32("jvs.hnum", "Remaining", base.DEC)
jvsio_proto.fields.hstat = ProtoField.string("jvs.hstat", "Status")
jvsio_proto.fields.id = ProtoField.string("jvs.id", "ID")
jvsio_proto.fields.input = ProtoField.uint8("jvs.input", "SW Inputs", base.HEX)
jvsio_proto.fields.line = ProtoField.uint8("jvs.line", "Line", base.DEC)
jvsio_proto.fields.node = ProtoField.uint8("jvs.node", "Node", base.DEC)
jvsio_proto.fields.player = ProtoField.uint8("jvs.player", "Player", base.DEC)
jvsio_proto.fields.report = ProtoField.uint8("jvs.report", "Report", base.HEX)
jvsio_proto.fields.slot = ProtoField.uint8("jvs.slot", "Slot", base.DEC)
jvsio_proto.fields.status = ProtoField.uint8("jvs.status", "Status", base.HEX)
jvsio_proto.fields.sum = ProtoField.uint8("jvs.sum", "Sum", base.HEX)
jvsio_proto.fields.sw = ProtoField.uint16("jvs.sw", "SW", base.HEX)
jvsio_proto.fields.sync = ProtoField.uint8("jvs.sync", "Sync", base.HEX)
jvsio_proto.fields.version = ProtoField.uint8("jvs.ver", "Version", base.DEC)
jvsio_proto.fields.wdata = ProtoField.uint16("jvs.wdata", "Data", base.HEX)
jvsio_proto.fields.xbit = ProtoField.uint8("jvs.xbit", "Xbit", base.DEC)
jvsio_proto.fields.xpos = ProtoField.uint16("jvs.xpos", "X Position", base.DEC)
jvsio_proto.fields.ybit = ProtoField.uint8("jvs.ybit", "Ybit", base.DEC)
jvsio_proto.fields.ypos = ProtoField.uint16("jvs.ypos", "Y Position", base.DEC)

-- Host to Node command string
local command_string = {
  nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
  "Get I/O ID", -- 0x10
  "Get Command Rev",
  "Get JV Rev",
  "Get Comm Rev",
  "Get Function",
  "Mainboard ID",
  nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
  "Get SW Input", -- 0x20
  "Get Coin Input",
  "Get Analog Input",
  "Get Rotary Input",
  "Get Keycode Input",
  "Get Screen Position Input",
  "Get General Purpose SW Input",
  nil, nil, nil, nil, nil, nil, nil,
  "Get Remaining Payout",
  "Retry",
  "Sub Coin", -- 0x30
  "Add Payout",
  "Set General Purpose Output 1",
  "Set Analog Output",
  "Set Character Output",
  "Add Coin",
  "Sub Payout",
  "Set General Purpose Output 2",
  "Set General Purpose Output 3",
}
command_string[0xf0] = "Reset"
command_string[0xf1] = "Set Address"

-- Node to Host status string
local status_string = {
  "OK",
  "Unknown Command",
  "SUM Error",
  "Ack Overflow",
}

-- Node to Host report string
local report_string = {
  "OK",
  "Parameter Error, No Data",
  "Parameter Error, Ignored",
  "Busy",
}

-- Coin condition string for a report
local condition_string = {
  "OK",
  "Error",
  "Offline",
  "Busy",
}

-- Function code to string table for Get Function
local function_string = {
  "SW Input",
  "Coin Input",
  "Analog Input",
  "Rotary Input",
  "Keycode Input",
  "Screen Position Input",
  "General Purpose SW Input",
  nil, nil, nil, nil, nil, nil, nil, nil,
  "Card System",
  "Medal Hopper",
  "General Purpose Driver",
  "Analog Output",
  "Character Output",
  "Backup",
}

-- Remember parsed Host to Node commands in the following format;
-- {
--   <frame id 1>: {
--     code: <command code>,
--     args: {
--       <parameter name 1>: <parameter value 1>,
--       <parameter name 2>: <parameter value 2>,
--       ...
--     }
--   },
--   <frame id 2>: { ... },
--   ...
-- }
-- Used to parse a report, based on a corresponding command
local command_table = {}

-- Remember parsed destination nodes in the following format;
-- {
--   <frame id 1>: <node 1>,
--   <frame id 2>: <node 2>,
--   ...
-- }
-- Used to determine the source node for the reports
local destination_table = {}

-- String binary format; 0x13 => "0001_0011" for SW reports
function binary_to_string(bin)
  local s = {}
  for i = 0, 8 do
    s[i] = tostring(bin % 2)
    bin = math.floor(bin / 2)
  end
  return s[7] .. s[6] .. s[5] .. s[4] .. "_" .. s[3] .. s[2] .. s[1] .. s[0]
end

-- Count null-terminated string length
function count_null_terminated_string(buffer)
  for i = 0, buffer:len() do
    if buffer(i, 1):uint() == 0 then
      return i
    end
  end
  return buffer:len()
end

-- Get hopper status string
function get_hopper_status_string(status)
  local s = {}
  status = math.floor(status / 16)
  if status % 2 == 1 then
    table.insert(s, "Coin Empty")
  end
  status = math.floor(status / 2)
  if status % 2 == 1 then
    table.insert(s, "Coin Low")
  end
  status = math.floor(status / 2)
  if status % 2 == 1 then
    table.insert(s, "Jamm")
  end
  status = math.floor(status / 2)
  if status % 2 == 1 then
    table.insert(s, "Busy")
  end
  return table.concat(s, " / ")
end

-- Calculate command length
function get_command_length(buffer)
  local command_length = {
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    1, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    3, 2, 2, 2, 1, 2, 2, nil, nil, nil, nil, nil, nil, nil, 2, 1,
    4, 4, nil, nil, nil, 4, 4, 3, 3,
  }
  local command = buffer(0, 1):uint()
  if 0xf0 <= command and command <= 0xf2 then
    return 2
  elseif command == 0x15 then
    return count_null_terminated_string(buffer:range(1)) + 2
  elseif command == 0x32 or command == 0x34 then
    return buffer(1, 1):uint() + 2
  elseif command == 0x33 then
    return buffer(1, 1):uint() * 2 + 2
  end
  return command_length[command]
end

-- Calculate report length
function get_report_length(buffer, command)
  if command.code == 0x10 then -- Get I/O ID
    return count_null_terminated_string(buffer:range(1)) + 2
  elseif 0x11 <= command.code and command.code <= 0x13 then
    return 2
  elseif command.code == 0x14 then -- Get Function
    for i = 1, buffer:len() - 1, 4 do
      if buffer(i, 1):uint() == 0 then
        return i + 1
      end
    end
    return buffer:len()
  elseif command.code == 0x20 then -- Get SW Input
    return 2 + command.args.player * command.args.byte
  elseif command.code == 0x21 then -- Get Coin Input
    return 1 + 2 * command.args.slot
  elseif command.code == 0x22 or -- Get Analog Input
      command.code == 0x23 then -- Get Rotary Input
    return 1 + command.args.channel * 2
  elseif command.code == 0x24 then -- Get Keycode Input
    return 2
  elseif command.code == 0x25 or  -- Get Screen Position Input
      command.code == 0x2e then -- Get Remaining Payout
    return 5
  elseif command.code == 0x26 then -- Get General Purpose SW Input
    return 1 + command.args.byte
  end
  return 1
end

-- Parse a command and returns parameter table that will be used by a report.
function parse_command(pinfo, jvsio, buffer)
  -- Parameter table.
  local args = {}

  local command_length = get_command_length(buffer)
  if buffer:len() < command_length then
    return args
  end

  local command = buffer(0, 1):uint()
  local subtree = jvsio:add(
      jvsio_proto, buffer(0, command_length),
      command_string[command] or "Unknown")
  subtree:add(jvsio_proto.fields.command, buffer(0, 1))

  if command == 0x15 then
    subtree:add(jvsio_proto.fields.id, buffer(1, command_length - 2):string())
  elseif command == 0x20 then
    subtree:add(jvsio_proto.fields.player, buffer(1, 1))
    subtree:add(jvsio_proto.fields.byte, buffer(2, 1))
    args.player = buffer(1, 1):uint()
    args.byte = buffer(2, 1):uint()
  elseif command == 0x21 then
    subtree:add(jvsio_proto.fields.slot, buffer(1, 1))
    args.slot = buffer(1, 1):uint()
  elseif command == 0x22 or command == 0x23 then
    subtree:add(jvsio_proto.fields.channel, buffer(1, 1))
    args.channel = buffer(1, 1):uint()
  elseif command == 0x25 or command == 0x2e then
    subtree:add(jvsio_proto.fields.channel, buffer(1, 1))
  elseif command == 0x26 then
    subtree:add(jvsio_proto.fields.byte, buffer(1, 1))
    args.byte = buffer(1, 1):uint()
  elseif command == 0x30 or command == 0x31 or command == 0x35 or
      command == 0x36 then
    subtree:add(jvsio_proto.fields.slot, buffer(1, 1))
    subtree:add(jvsio_proto.fields.coin, buffer(2, 2))
  elseif command == 0x32 or command == 0x34 then
    subtree:add(jvsio_proto.fields.byte, buffer(1, 1))
    local byte = buffer(1, 1):uint()
    for i = 2, 1 + byte do
      subtree:add(jvsio_proto.fields.data, buffer(i, 1))
    end
  elseif command == 0x33 then
    subtree:add(jvsio_proto.fields.channel, buffer(1, 1))
    for i = 2, 1 + byte * 2, 2 do
      subtree:add(jvsio_proto.fields.wdata, buffer(i, 2))
    end
  elseif command == 0x37 then
    subtree:add(jvsio_proto.fields.bytep, buffer(1, 1))
    subtree:add(jvsio_proto.fields.data, buffer(2, 1))
  elseif command == 0x38 then
    subtree:add(jvsio_proto.fields.bitp, buffer(1, 1))
    subtree:add(jvsio_proto.fields.data, buffer(2, 1))
  elseif command == 0xf0 then
    local guard = buffer(1, 1):uint()
    subtree:add(jvsio_proto.fields.guard, buffer(1, 1), guard, nil,
        guard == 0xd9 and "" or "(Broken)")
  elseif command == 0xf1 then
    subtree:add(jvsio_proto.fields.address, buffer(1, 1))
    destination_table[pinfo.number] = buffer(1, 1):uint()
  end
  return args
end

-- Parse one function report for Get Function
function parse_function(tree, buffer)
  local func = buffer(0, 1):uint()
  if func == 0x01 then
    tree:add(jvsio_proto.fields.player, buffer(1, 1))
    tree:add(jvsio_proto.fields.button, buffer(2, 1))
  elseif func == 0x02 or func == 0x10 or func == 0x12 then
    tree:add(jvsio_proto.fields.slot, buffer(1, 1))
  elseif func == 0x03 then
    tree:add(jvsio_proto.fields.channel, buffer(1, 1))
    tree:add(jvsio_proto.fields.bit, buffer(2, 1))
  elseif func == 0x04 or func == 0x11 or func == 0x13 then
    tree:add(jvsio_proto.fields.channel, buffer(1, 1))
  elseif func == 0x06 then
    tree:add(jvsio_proto.fields.xbit, buffer(1, 1))
    tree:add(jvsio_proto.fields.ybit, buffer(2, 1))
    tree:add(jvsio_proto.fields.channel, buffer(3, 1))
  elseif func == 0x07 then
    tree:add(jvsio_proto.fields.sw, buffer(1, 2))
  elseif func == 0x14 then
    tree:add(jvsio_proto.fields.chr, buffer(1, 1))
    tree:add(jvsio_proto.fields.line, buffer(2, 1))
    tree:add(jvsio_proto.fields.code, buffer(3, 1))
  end
end

-- Parse one report and return the report size
function parse_report(jvsio, buffer, command)
  local length = get_report_length(buffer, command)
  if buffer:len() <= length then
    return 0
  end

  local subtree = jvsio:add(jvsio_proto, buffer(0, length), string.format(
      "Report for %s", command_string[command.code] or "Unknown"))
  local report = buffer(0, 1):uint()
  subtree:add(jvsio_proto.fields.report, buffer(0, 1), report, nil,
      report_string[report] or "Unknown")

  if command.code == 0x10 then -- Get I/O ID
    subtree:add(jvsio_proto.fields.id, buffer(1, length - 1),
        buffer(1, length - 1):string())
  elseif 0x11 <= command.code and command.code <= 0x13 then
    subtree:add(jvsio_proto.fields.version, buffer(1, 1))
  elseif command.code == 0x14 then -- Get Function
    for i = 1, buffer:len() - 1, 4 do
      local func = buffer(i, 1):uint();
      if func == 0 then
        break
      end
      parse_function(subtree:add(jvsio_proto, buffer(i, 4),
          function_string[func] or "Unknown"), buffer:range(i))
    end
  elseif command.code == 0x20 then -- Get SW Input
    local system = subtree:add(jvsio_proto, buffer(1, 1), "System")
    system:add(jvsio_proto.fields.input, buffer(1, 1), buffer(1, 1):uint(), nil,
        binary_to_string(buffer(1, 1):uint()))
    for i = 1, command.args.player do
      local player = subtree:add(jvsio_proto,
          buffer(2 + (i - 1) * command.args.byte, command.args.byte),
          string.format("Player %d", i))
      for j = 2 + (i - 1) * command.args.byte, 1 + i * command.args.byte do
        player:add(jvsio_proto.fields.input, buffer(j, 1), buffer(j, 1):uint(),
            nil, binary_to_string(buffer(j, 1):uint()))
      end
    end
  elseif command.code == 0x21 then -- Get Coin Input
    for i = 1, command.args.slot do
      local slot = subtree:add(jvsio_proto, buffer(i * 2 - 1, 2),
          string.format("Slot %d", i))
      local cond = buffer(i * 2 - 1, 1):uint()
      local coin = buffer(i * 2, 1):uint() + (cond % 64) * 256
      cond = math.floor(cond / 64)
      slot:add(jvsio_proto.fields.condition,
          buffer(i * 2 - 1, 1),
          condition_string[cond] or "Unknown")
      slot:add(jvsio_proto.fields.coin, buffer(i * 2 - 1, 2), coin)
    end
  elseif command.code == 0x22 or -- Get Analog Input
      command.code == 0x23 then -- Get Rotary Input
    for i = 1, command.args.channel do
      subtree:add(jvsio_proto.fields.wdata, buffer(i * 2 - 1, 2))
    end
  elseif command.code == 0x24 then -- Get Keycode Input
    subtree:add(jvsio_proto.fields.chr, buffer(1, 1))
  elseif command.code == 0x25 then -- Get Screen Position Input
    subtree:add(jvsio_proto.fields.xpos, buffer(1, 2))
    subtree:add(jvsio_proto.fields.ypos, buffer(3, 2))
  elseif command.code == 0x26 then -- Get General Purpose SW Input
    for i = 1, buffer:length() - 1 do
      subtree:add(jvsio_proto.fields.data, buffer(i, 1))
    end
  elseif command.code == 0x2e then -- Get Remaining Payout
      subtree:add(jvsio_proto.fields.hstat, buffer(1, 1),
          get_hopper_status_string(buffer( 1, 1):uint()))
      subtree:add(jvsio_proto.fields.hnum, buffer(2, 3))
  end
  return length
end

function jvsio_proto.dissector(buffer, pinfo, tree)
  -- check magic code.
  if buffer:len() < 4 or buffer(0, 4):string() ~= "JVS@" then
    return
  end
  buffer = buffer:range(4)
  pinfo.cols.protocol = jvsio_proto.name
  pinfo.cols.info = "[Broken]"

  local jvsio = tree:add(jvsio_proto, buffer(), "JVS I/O")

  -- SYNC
  if buffer:len() < 1 or buffer(0, 1):uint() ~= 0xe0 then
    return
  end
  jvsio:add(jvsio_proto.fields.sync, buffer(0, 1))

  -- Calculate SUM beforehand
  local sum = 0
  for i = 1, buffer:len() - 2 do
    sum = sum + buffer(i, 1):uint()
  end
  sum = sum % 0x100

  -- NODE
  local is_report = false
  if buffer:len() >= 2 then
    local comment = ""
    local node = buffer(1, 1):uint()
    if node == 0 then
      comment = "Host"
      pinfo.cols.src = destination_table[pinfo.number - 1]
      pinfo.cols.dst = "Host"
      is_report = true
    elseif node == 0xff then
      comment = "Broadcast"
      pinfo.cols.src = "Host"
      pinfo.cols.dst = "Broadcast"
    else
      comment = "Client"
      pinfo.cols.src = "Host"
      pinfo.cols.dst = node
      destination_table[pinfo.number] = node
    end
    jvsio:add(jvsio_proto.fields.node, buffer(1, 1), buffer(1, 1):uint(), nil,
        comment)
  else
    return
  end

  -- BYTE
  local is_broken = false
  if buffer:len() >= 3 then
    local length = buffer(2, 1):uint()
    jvsio:add(jvsio_proto.fields.byte, buffer(2, 1), length, nil,
        buffer:len() == length + 3 and "" or "(Broken)")
  end
  if buffer:len() <= 3 then
    return
  end
  buffer = buffer:range(3)

  -- DATA
  local info = {}
  if is_report then
    -- REPORT
    local status_code = buffer(0, 1):uint()
    local status = status_string[status_code] or "Unknown"
    jvsio:add(jvsio_proto.fields.status, buffer(0, 1), status_code, nil, status)
    table.insert(info, "Status")
    buffer = buffer:range(1)

    local command = command_table[pinfo.number - 1]
    if command ~= nil then
      for i = 1, #command do
        if buffer:len() <= 1 then
          break
        end
        local parsed_length = parse_report(jvsio, buffer, command[i])
        if parsed_length == 0 then
          is_broken = true
          break
        end
        buffer = buffer:range(parsed_length)
      end
    end
  else
    -- COMMAND
    local commands = {}
    while buffer:len() > 1 do
      local command_length = get_command_length(buffer)
      if buffer:len() < command_length then
        is_broken = true
        break
      end
      local command = {}
      command.code = buffer(0, 1):uint()
      table.insert(info, command_string[command.code] or "Unknown")
      command.args = parse_command(pinfo, jvsio, buffer)
      table.insert(commands, command)
      buffer = buffer:range(command_length)
    end
    command_table[pinfo.number] = commands
  end

  -- SUM
  if buffer:len() ~= 1 then
    is_broken = true
  elseif buffer:len() == 1 then
    local sum_value = buffer(buffer:len() - 1, 1):uint()
    is_broken = sum_value ~= sum
    jvsio:add(jvsio_proto.fields.sum, buffer(0, 1), sum_value, nil,
        is_broken and string.format("(Broken, actual: 0x%02x)", sum) or "")
  end

  pinfo.cols.info =
      (is_broken and "[Broken] " or "") .. table.concat(info, " / ")
end

register_postdissector(jvsio_proto)
