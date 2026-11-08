// bits_test.mbt
//
// BitWriter 的 MSB-first 位序、字节对齐填充与 UTF-8 变长数边界值。

///|
test "write_bits MSB-first packing" {
  let w = BitWriter::new()
  w.write_bits(0b101U, 3)
  w.write_bits(0b011U, 3)
  let got = w.to_bytes()
  assert_eq(got.length(), 1)
  assert_eq(got.unsafe_get(0).to_int(), 0xAC)
}

///|
test "write_bits spans byte boundary" {
  let w = BitWriter::new()
  w.write_bits(0b10101U, 5)
  w.write_bits(0b111U, 3)
  let got = w.to_bytes()
  assert_eq(got.length(), 1)
  assert_eq(got.unsafe_get(0).to_int(), 0b10101111)
}

///|
test "write 36-bit field with 32-bit value" {
  let w = BitWriter::new()
  w.write_bits(0x12345U, 36)
  let got = w.to_bytes()
  assert_eq(got.length(), 5)
  assert_eq(got.unsafe_get(0).to_int(), 0x00)
  assert_eq(got.unsafe_get(1).to_int(), 0x00)
  assert_eq(got.unsafe_get(2).to_int(), 0x12)
  assert_eq(got.unsafe_get(3).to_int(), 0x34)
  assert_eq(got.unsafe_get(4).to_int(), 0x50)
}

///|
test "align pads zeros at the LSB side" {
  let w = BitWriter::new()
  w.write_bits(0b1U, 1)
  w.align()
  let got = w.to_bytes()
  assert_eq(got.length(), 1)
  assert_eq(got.unsafe_get(0).to_int(), 0x80)
}

///|
test "to_bytes auto-aligns unaligned tail" {
  let w = BitWriter::new()
  w.write_bits(0b101U, 3)
  let got = w.to_bytes()
  assert_eq(got.length(), 1)
  assert_eq(got.unsafe_get(0).to_int(), 0xA0)
}

///|
test "write_bytes after byte-aligned bits" {
  let w = BitWriter::new()
  w.write_bits(0xABU, 8)
  w.write_bytes(b"CD")
  let got = w.to_bytes()
  assert_eq(got.length(), 3)
  assert_eq(got.unsafe_get(0).to_int(), 0xAB)
  assert_eq(got.unsafe_get(1).to_int(), 0x43)
  assert_eq(got.unsafe_get(2).to_int(), 0x44)
}

///|
fn utf8_bytes(v : UInt) -> Bytes {
  let w = BitWriter::new()
  w.write_utf8(v)
  w.to_bytes()
}

///|
test "utf8 one-byte boundary 0x7F" {
  let got = utf8_bytes(0x7FU)
  assert_eq(got.length(), 1)
  assert_eq(got.unsafe_get(0).to_int(), 0x7F)
}

///|
test "utf8 two-byte boundaries 0x80 / 0x7FF" {
  let lo = utf8_bytes(0x80U)
  assert_eq(lo.length(), 2)
  assert_eq(lo.unsafe_get(0).to_int(), 0xC2)
  assert_eq(lo.unsafe_get(1).to_int(), 0x80)
  let hi = utf8_bytes(0x7FFU)
  assert_eq(hi.length(), 2)
  assert_eq(hi.unsafe_get(0).to_int(), 0xDF)
  assert_eq(hi.unsafe_get(1).to_int(), 0xBF)
}

///|
test "utf8 three-byte boundaries 0x800 / 0xFFFF" {
  let lo = utf8_bytes(0x800U)
  assert_eq(lo.length(), 3)
  assert_eq(lo.unsafe_get(0).to_int(), 0xE0)
  assert_eq(lo.unsafe_get(1).to_int(), 0xA0)
  assert_eq(lo.unsafe_get(2).to_int(), 0x80)
  let hi = utf8_bytes(0xFFFFU)
  assert_eq(hi.length(), 3)
  assert_eq(hi.unsafe_get(0).to_int(), 0xEF)
  assert_eq(hi.unsafe_get(1).to_int(), 0xBF)
  assert_eq(hi.unsafe_get(2).to_int(), 0xBF)
}

///|
test "utf8 four-byte boundaries 0x10000 / 0x1FFFFF" {
  let lo = utf8_bytes(0x10000U)
  assert_eq(lo.length(), 4)
  assert_eq(lo.unsafe_get(0).to_int(), 0xF0)
  assert_eq(lo.unsafe_get(1).to_int(), 0x90)
  assert_eq(lo.unsafe_get(2).to_int(), 0x80)
  assert_eq(lo.unsafe_get(3).to_int(), 0x80)
  let hi = utf8_bytes(0x1FFFFFU)
  assert_eq(hi.length(), 4)
  assert_eq(hi.unsafe_get(0).to_int(), 0xF7)
  assert_eq(hi.unsafe_get(1).to_int(), 0xBF)
  assert_eq(hi.unsafe_get(2).to_int(), 0xBF)
  assert_eq(hi.unsafe_get(3).to_int(), 0xBF)
}
