// metadata.mbt
//
// 元数据块构造。v1 只写一个 STREAMINFO（规范要求它是第一个块，
// 之后没有别的块，故 is_last=1）。STREAMINFO 载荷 34 字节，字段
// 位宽 16+16+24+24+20+3+5+36+128 = 272 位，MSB-first 紧排
// （跨字节），MD5 摘要按字节直写。

///|
/// 构造 STREAMINFO 块载荷（34 字节，不含块头）。
pub fn streaminfo_payload(
  block_size : Int,
  sample_rate : Int,
  channels : Int,
  bps : Int,
  total_samples : UInt,
  md5 : FixedArray[Byte],
) -> Bytes {
  let w = BitWriter::new()
  w.write_bits(block_size.reinterpret_as_uint(), 16) // min block size
  w.write_bits(block_size.reinterpret_as_uint(), 16) // max block size
  w.write_bits(0U, 24) // min frame size（未知，按 0 写）
  w.write_bits(0U, 24) // max frame size（未知，按 0 写）
  w.write_bits(sample_rate.reinterpret_as_uint(), 20)
  w.write_bits((channels - 1).reinterpret_as_uint(), 3)
  w.write_bits((bps - 1).reinterpret_as_uint(), 5)
  w.write_bits(total_samples, 36)
  w.align()
  for i = 0; i < 16; i = i + 1 {
    w.buf.write_byte(md5[i])
  }
  w.to_bytes()
}

///|
/// 构造元数据块：1 位 is_last + 7 位类型 + 24 位载荷长度 + 载荷。
pub fn metadata_block(block_type : Int, is_last : Bool, payload : Bytes) -> Bytes {
  let w = BitWriter::new()
  w.write_bits(if is_last { 1U } else { 0U }, 1)
  w.write_bits(block_type.reinterpret_as_uint(), 7)
  w.write_bits(payload.length().reinterpret_as_uint(), 24)
  w.align()
  w.write_bytes(payload)
  w.to_bytes()
}
