// bits.mbt
//
// FLAC 码流是 MSB-first 位序：帧头、子帧、残差全部先写高位。
// BitWriter 把位累积成字节写出。write_bits 保持 nbits < 8 的不变式，
// 单次可写 1..36 位（STREAMINFO 的 total_samples 是 36 位字段），
// 值必须落在低 n 位内（36 位字段配合 32 位值 = 高 4 位自动为零）。
// 字节对齐后可 write_bytes 直接写整字节（如 MD5 摘要）。

///|
/// MSB-first 位写入器。
pub(all) struct BitWriter {
  buf : @buffer.Buffer
  mut acc : UInt
  mut nbits : Int
}

///|
/// 新建空写入器。
pub fn BitWriter::new() -> BitWriter {
  { buf: @buffer.Buffer(), acc: 0, nbits: 0 }
}

///|
/// 写 value 的低 n 位（先写高位）。
pub fn BitWriter::write_bits(self : BitWriter, value : UInt, n : Int) -> Unit {
  let v = value
  let mut rem = n
  while rem > 0 {
    let take = if 8 - self.nbits < rem { 8 - self.nbits } else { rem }
    let shift = rem - take
    let mask = (1U << take) - 1U
    // js 后端的移位按 32 取模：shift >= 32 时结果恒为 0，不能真的执行移位。
    let chunk : UInt = if shift >= 32 { 0U } else { (v >> shift) & mask }
    self.acc = (self.acc << take) | chunk
    self.nbits = self.nbits + take
    if self.nbits == 8 {
      self.buf.write_byte(self.acc.to_byte())
      self.acc = 0
      self.nbits = 0
    }
    rem = rem - take
  }
}

///|
/// 写单比特。
pub fn BitWriter::write_bit(self : BitWriter, b : Bool) -> Unit {
  self.write_bits(if b { 1U } else { 0U }, 1)
}

///|
/// 零填充到字节边界（子帧之间、帧尾 CRC-16 之前必须对齐）。
pub fn BitWriter::align(self : BitWriter) -> Unit {
  if self.nbits > 0 {
    self.buf.write_byte((self.acc << (8 - self.nbits)).to_byte())
    self.acc = 0
    self.nbits = 0
  }
}

///|
/// 直接写整字节（调用前必须已对齐）。
pub fn BitWriter::write_bytes(self : BitWriter, data : Bytes) -> Unit {
  self.buf.write_bytes(data)
}

///|
/// 取出已写字节（若有未对齐的残留位，先零填充对齐）。
pub fn BitWriter::to_bytes(self : BitWriter) -> Bytes {
  self.align()
  self.buf.to_bytes()
}

///|
/// 写 UTF-8 变长编码数（FLAC 帧号/样本号，字节级写入，调用前必须已
/// 对齐）。值域 ≤ 0x1FFFFF（四字节 UTF-8）；固定分块下帧号不会超出。
pub fn BitWriter::write_utf8(self : BitWriter, value : UInt) -> Unit {
  if self.nbits != 0 {
    abort("write_utf8 requires byte-aligned writer")
  }
  if value < 0x80U {
    self.buf.write_byte(value.to_byte())
  } else if value < 0x800U {
    self.buf.write_byte((0xC0U | (value >> 6)).to_byte())
    self.buf.write_byte((0x80U | (value & 0x3FU)).to_byte())
  } else if value < 0x10000U {
    self.buf.write_byte((0xE0U | (value >> 12)).to_byte())
    self.buf.write_byte((0x80U | ((value >> 6) & 0x3FU)).to_byte())
    self.buf.write_byte((0x80U | (value & 0x3FU)).to_byte())
  } else if value < 0x200000U {
    self.buf.write_byte((0xF0U | (value >> 18)).to_byte())
    self.buf.write_byte((0x80U | ((value >> 12) & 0x3FU)).to_byte())
    self.buf.write_byte((0x80U | ((value >> 6) & 0x3FU)).to_byte())
    self.buf.write_byte((0x80U | (value & 0x3FU)).to_byte())
  } else {
    abort("utf8 coded number out of range")
  }
}
