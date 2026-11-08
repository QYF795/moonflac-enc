// metadata_test.mbt
//
// STREAMINFO 载荷的字段级验证：测试内实现一个 MSB-first 位读取器，
// 逐字段读回与写入值比对（自洽 + 覆盖跨字节位排布），另附一个
// 手工推演的整块黄金字节向量（bps=8/ch=1/rate=8000/bs=192/total=0/
// MD5=0）。

struct TestBitReader {
  data : Bytes
  mut bitpos : Int
}

fn TestBitReader::new(data : Bytes) -> TestBitReader {
  { data: data, bitpos: 0 }
}

fn TestBitReader::read_bits(self : TestBitReader, n : Int) -> UInt {
  let mut acc = 0U
  let mut rem = n
  while rem > 0 {
    let byte_index = self.bitpos / 8
    let bit_in_byte = self.bitpos % 8
    let take = if 8 - bit_in_byte < rem { 8 - bit_in_byte } else { rem }
    let byte = self.data.unsafe_get(byte_index).to_int()
    let shift = 8 - bit_in_byte - take
    let mask = (1 << take) - 1
    let chunk = (byte >> shift) & mask
    acc = (acc << take) | chunk.reinterpret_as_uint()
    self.bitpos = self.bitpos + take
    rem = rem - take
  }
  acc
}

test "streaminfo fields roundtrip through bit reader" {
  let md5 = FixedArray::make(16, (0xAB).to_byte())
  let payload = streaminfo_payload(1152, 44100, 2, 16, 2000U, md5)
  assert_eq(payload.length(), 34)
  let r = TestBitReader::new(payload)
  assert_eq(r.read_bits(16).reinterpret_as_int(), 1152) // min block size
  assert_eq(r.read_bits(16).reinterpret_as_int(), 1152) // max block size
  assert_eq(r.read_bits(24).reinterpret_as_int(), 0) // min frame size
  assert_eq(r.read_bits(24).reinterpret_as_int(), 0) // max frame size
  assert_eq(r.read_bits(20).reinterpret_as_int(), 44100) // sample rate
  assert_eq(r.read_bits(3).reinterpret_as_int(), 1) // channels - 1
  assert_eq(r.read_bits(5).reinterpret_as_int(), 15) // bps - 1
  assert_eq(r.read_bits(36).reinterpret_as_int(), 2000) // total samples
  // 前 272 位之后应落在字节边界（272 = 34 字节整），接着是 16 字节 MD5
  assert_eq(r.bitpos % 8, 0)
  for i = 0; i < 16; i = i + 1 {
    assert_eq(payload.unsafe_get(18 + i).to_int(), 0xAB)
  }
}

test "streaminfo golden bytes for 8-bit mono 8kHz block 192" {
  // 手工推演：192=0x00C0（b0-3）；min/max frame size=0（b4-10）；
  // 采样率 8000=0x1F40（20 位，位 80-99 → b11=0x01, b12=0xF4）；
  // channels-1=000（位 100-102）+ bps-1=00111（位 103-107）→ b13=0x70；
  // total_samples=0（36 位，位 108-143 → b13 高 4 位+b14-17 全零）；MD5 全零
  let payload = streaminfo_payload(
    192,
    8000,
    1,
    8,
    0U,
    FixedArray::make(16, (0).to_byte()),
  )
  let expected = [
    0x00, 0xC0, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0xF4, 0x00, 0x70, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00,
  ]
  assert_eq(payload.length(), 34)
  for i = 0; i < 34; i = i + 1 {
    assert_eq(payload.unsafe_get(i).to_int(), expected[i])
  }
}

test "metadata block header bytes" {
  // 1 位 is_last=1 + 7 位类型=0 + 24 位长度=34 → 0x80 0x00 0x00 0x22
  let payload = Bytes::make(34, b'\x00')
  let block = metadata_block(0, true, payload)
  assert_eq(block.length(), 38)
  assert_eq(block.unsafe_get(0).to_int(), 0x80)
  assert_eq(block.unsafe_get(1).to_int(), 0x00)
  assert_eq(block.unsafe_get(2).to_int(), 0x00)
  assert_eq(block.unsafe_get(3).to_int(), 0x22)
  assert_eq(block.unsafe_get(4).to_int(), 0x00) // 载荷首字节
  assert_eq(block.unsafe_get(37).to_int(), 0x00) // 载荷末字节
}
