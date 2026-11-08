// frame.mbt
//
// 帧组装：帧头（14 位同步码 + 分块策略 + 各编码字段 + UTF-8 帧号，
// 32 位定长部分 + 可选 16 位块大小扩展，恰好字节对齐）→ CRC-8 →
// 各声道子帧 → 零填充到字节边界 → CRC-16（覆盖帧起始到填充处）。
// v1 决策：固定分块（strategy=0；末帧可短，解码端按 STREAMINFO 的
// total_samples 截断）；采样率码/位深码均取「取自 STREAMINFO」；
// 块大小优先表码，其余走 16 位扩展（0111）。

///|
/// 块大小 → (4 位表码, 是否需要 16 位扩展字段)。
fn block_size_code(block_size : Int) -> (Int, Bool) {
  if block_size == 192 {
    (1, false)
  } else if block_size == 576 {
    (2, false)
  } else if block_size == 1152 {
    (3, false)
  } else if block_size == 2304 {
    (4, false)
  } else if block_size == 4608 {
    (5, false)
  } else if block_size == 256 {
    (8, false)
  } else if block_size == 512 {
    (9, false)
  } else if block_size == 1024 {
    (10, false)
  } else if block_size == 2048 {
    (11, false)
  } else if block_size == 4096 {
    (12, false)
  } else if block_size == 8192 {
    (13, false)
  } else if block_size == 16384 {
    (14, false)
  } else if block_size == 32768 {
    (15, false)
  } else {
    (7, true)
  }
}

///|
/// 组装一帧（含 CRC-8 与 CRC-16）。samples 为 planar 样本，
/// 本帧取每声道 [from, from+len)。
pub fn build_frame(
  block_size : Int,
  channels : Int,
  bps : Int,
  frame_number : UInt,
  samples : Array[Array[Int32]],
  from : Int,
  len : Int,
  mode : SubframeMode,
) -> Bytes {
  // 帧头：32 位定长部分 + UTF-8 帧号 + 可选 16 位块大小，均字节对齐
  let h = BitWriter::new()
  h.write_bits(0x3FFEU, 14) // 同步码 11111111111110
  h.write_bits(0U, 1) // 保留位
  h.write_bits(0U, 1) // 分块策略：0 = 固定分块
  let (code, needs_ext) = block_size_code(block_size)
  h.write_bits(code.reinterpret_as_uint(), 4) // 块大小码
  h.write_bits(0U, 4) // 采样率码 0000 = 取自 STREAMINFO
  h.write_bits((channels - 1).reinterpret_as_uint(), 4) // 声道分配
  h.write_bits(0U, 3) // 位深码 000 = 取自 STREAMINFO
  h.write_bits(0U, 1) // 保留位
  h.write_utf8(frame_number)
  if needs_ext {
    // 块大小码 0111 的 16 位扩展存「块大小 − 1」（RFC 9639 §9.2.2）
    h.write_bits((block_size - 1).reinterpret_as_uint(), 16)
  }
  h.align()
  let header = h.to_bytes()
  // 帧体 = 帧头 + CRC-8 + 各声道子帧 + 零填充
  let w = BitWriter::new()
  w.write_bytes(header)
  w.buf.write_byte(crc8(header).to_byte())
  for c = 0; c < channels; c = c + 1 {
    match mode {
      Verbatim => encode_verbatim(w, samples[c], from, len, bps)
    }
  }
  w.align()
  let body = w.to_bytes()
  // CRC-16 覆盖帧体全部字节，结果 MSB-first 附在帧尾
  let fcrc = crc16(body)
  let out = @buffer.Buffer()
  out.write_bytes(body)
  out.write_byte(((fcrc >> 8) & 0xFF).to_byte())
  out.write_byte((fcrc & 0xFF).to_byte())
  out.to_bytes()
}
