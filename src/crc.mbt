// crc.mbt
//
// FLAC 使用的两种循环冗余校验（多项式与覆盖范围以 FLAC 格式规范为准，
// 已知向量测试见 crc_test.mbt）：
// - CRC-8：x^8+x^2+x+1（0x07），覆盖帧头起始到 CRC-8 字节之前；
// - CRC-16：x^16+x^15+x^2+1（0x8005），覆盖帧起始到子帧字节对齐处。
// 两者都是 init=0、不反转、不异或输出、MSB-first 的直接计算。

///|
/// 对整个字节串计算 CRC-8（多项式 0x07）。
pub fn crc8(data : Bytes) -> Int32 {
  let mut c = 0
  for i = 0; i < data.length(); i = i + 1 {
    c = c ^ data.unsafe_get(i).to_int()
    for _b in 0..<8 {
      c = if (c & 0x80) != 0 {
        ((c << 1) ^ 0x07) & 0xFF
      } else {
        (c << 1) & 0xFF
      }
    }
  }
  c
}

///|
/// 对整个字节串计算 CRC-16（多项式 0x8005）。
pub fn crc16(data : Bytes) -> Int32 {
  let mut c = 0
  for i = 0; i < data.length(); i = i + 1 {
    c = c ^ (data.unsafe_get(i).to_int() << 8)
    for _b in 0..<8 {
      c = if (c & 0x8000) != 0 {
        ((c << 1) ^ 0x8005) & 0xFFFF
      } else {
        (c << 1) & 0xFFFF
      }
    }
  }
  c
}
