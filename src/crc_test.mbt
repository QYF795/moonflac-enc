// crc_test.mbt
//
// CRC 已知向量（CRC catalogue / FLAC 实现通用验证值）：
// CRC-8（poly 0x07, init 0, 不反转）对 "123456789" 的校验值 = 0xF4；
// CRC-16/BUYPASS（poly 0x8005, init 0）对 "123456789" 的校验值 = 0xBB3D。
// 另附手工推演的 0x80 单字节向量（0x89 / 0x0280）。

///|
test "crc8 known vector 123456789" {
  assert_eq(crc8(b"123456789"), 0xF4)
}

///|
test "crc8 empty input" {
  assert_eq(crc8(b""), 0)
}

///|
test "crc8 single byte 0x80" {
  assert_eq(crc8(b"\x80"), 0x89)
}

///|
test "crc16 known vector 123456789" {
  assert_eq(crc16(b"123456789"), 0xFEE8)
}

///|
test "crc16 empty input" {
  assert_eq(crc16(b""), 0)
}

///|
test "crc16 single byte 0x80" {
  assert_eq(crc16(b"\x80"), 0x8303)
}
