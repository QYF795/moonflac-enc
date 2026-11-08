// frame_test.mbt
//
// 帧头字节布局与 CRC 覆盖范围的验证。帧头定长 32 位 + UTF-8 帧号；
// 块大小表码之外的尺寸走 16 位扩展（0111）。CRC-8 只覆盖帧头，
// CRC-16 覆盖帧体全部字节、结果 MSB-first 附在帧尾。

test "frame header layout for 1152/2ch/16bit frame 0" {
  let ch0 : Array[Int32] = [0x1234]
  let ch1 : Array[Int32] = [0x5678]
  let frame = build_frame(1152, 2, 16, 0U, [ch0, ch1], 0, 1, Verbatim)
  // 头部：同步码 11111111111110 + 保留 0 + 固定分块 0 + 块码 0011
  //       + 采样率 0000 + 声道分配 0001 + 位深 000 + 保留 0 → FF F8 30 10
  // UTF-8 帧号 0 → 0x00
  assert_eq(frame.unsafe_get(0).to_int(), 0xFF)
  assert_eq(frame.unsafe_get(1).to_int(), 0xF8)
  assert_eq(frame.unsafe_get(2).to_int(), 0x30)
  assert_eq(frame.unsafe_get(3).to_int(), 0x10)
  assert_eq(frame.unsafe_get(4).to_int(), 0x00)
  // CRC-8 覆盖前 5 字节帧头
  assert_eq(frame.unsafe_get(5).to_int(), crc8(frame[0:5].to_owned()))
  // 结构：5 头 + 1 crc8 + 2 声道 × (8 位子帧头 + 16 位样本) + 2 crc16
  assert_eq(frame.length(), 5 + 1 + 6 + 2)
  // CRC-16 覆盖帧体（帧尾前两字节为校验值），MSB-first
  assert_eq(frame.unsafe_get(12).to_int(), (crc16(frame[0:12].to_owned()) >> 8) & 0xFF)
  assert_eq(frame.unsafe_get(13).to_int(), crc16(frame[0:12].to_owned()) & 0xFF)
}

test "frame header uses 16-bit block size extension for non-table size" {
  let ch : Array[Int32] = [1, 2]
  let frame = build_frame(1000, 1, 16, 0U, [ch], 0, 2, Verbatim)
  // 块码 0111 + 采样率 0000 + 声道 0000 + 位深 000 + 保留 0 = 0x7000
  assert_eq(frame.unsafe_get(2).to_int(), 0x70)
  assert_eq(frame.unsafe_get(3).to_int(), 0x00)
  // UTF-8 帧号 0 之后是 16 位块大小扩展：999 = 0x03E7（存块大小 − 1）
  assert_eq(frame.unsafe_get(4).to_int(), 0x00)
  assert_eq(frame.unsafe_get(5).to_int(), 0x03)
  assert_eq(frame.unsafe_get(6).to_int(), 0xE7)
  // CRC-8 覆盖前 7 字节帧头
  assert_eq(frame.unsafe_get(7).to_int(), crc8(frame[0:7].to_owned()))
  // 帧体 = 7 头 + 1 crc8 + 子帧(8 位头 + 2×16 位样本) + 2 crc16
  assert_eq(frame.length(), 7 + 1 + 5 + 2)
}

test "frame number UTF-8 coding" {
  // 帧号 2000（0b11111010000，11 位）需 2 字节 UTF-8：
  // 110xxxxx 10xxxxxx → 2000>>6=31 → 0xDF，2000&0x3F=16 → 0x90
  let ch : Array[Int32] = [0]
  let frame = build_frame(192, 1, 8, 2000U, [ch], 0, 1, Verbatim)
  assert_eq(frame.unsafe_get(4).to_int(), 0xDF)
  assert_eq(frame.unsafe_get(5).to_int(), 0x90)
  assert_eq(frame.unsafe_get(6).to_int(), crc8(frame[0:6].to_owned()))
}
