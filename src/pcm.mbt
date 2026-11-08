// pcm.mbt
//
// PCM 输入解析：按 FLAC 惯例（交织小端、每样本恰好 bps/8 字节）
// 把原始字节解析成 planar 有符号样本。输出结构与 moonflac 解码
// 结果同构（声道 × 样本），往返比对因此可以逐样本进行。
// v1 位深支持 8/16/24/32（WAV 容器位宽），12/20 留待后续。

///|
/// 解析交织小端 PCM 为 planar 样本（声道 × 样本）。
pub fn parse_pcm(data : Bytes, channels : Int, bps : Int) -> Array[Array[Int32]] raise EncodeError {
  let bytes_per = bps / 8
  let row = channels * bytes_per
  if data.length() % row != 0 {
    raise InvalidInputSize
  }
  let frames = data.length() / row
  let out : Array[Array[Int32]] = []
  for _c in 0..<channels {
    let ch : Array[Int32] = []
    let mut off = _c * bytes_per
    for _f in 0..<frames {
      ch.push(read_sample_le(data, off, bps))
      off = off + row
    }
    out.push(ch)
  }
  out}

///|
/// 读一个 bps 位小端样本并符号扩展为 Int32。
fn read_sample_le(data : Bytes, off : Int, bps : Int) -> Int32 {
  if bps == 8 {
    let v = data.unsafe_get(off).to_int()
    if v >= 0x80 { v - 0x100 } else { v }
  } else if bps == 16 {
    let v = data.unsafe_get(off).to_int() | (data.unsafe_get(off + 1).to_int() << 8)
    if v >= 0x8000 { v - 0x10000 } else { v }
  } else if bps == 24 {
    let v = data.unsafe_get(off).to_int() |
      (data.unsafe_get(off + 1).to_int() << 8) |
      (data.unsafe_get(off + 2).to_int() << 16)
    if v >= 0x800000 { v - 0x1000000 } else { v }
  } else {
    data.unsafe_get(off).to_int() |
      (data.unsafe_get(off + 1).to_int() << 8) |
      (data.unsafe_get(off + 2).to_int() << 16) |
      (data.unsafe_get(off + 3).to_int() << 24)
  }
}
