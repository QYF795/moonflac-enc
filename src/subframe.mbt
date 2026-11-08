// subframe.mbt
//
// 子帧编码。子帧头 = 1 位 0 + 6 位类型码 + 1 位 wasted-bits 标志
// （0 = 无 wasted bits；1 = 后续存 k-1，k 为浪费位数）。
// v1 只有 VERBATIM（类型码 000001）：每样本按 bps 位原值写出。
// FIXED/LPC 在 M1/M2 引入（见 docs/design.md 级别映射）。

///|
/// 子帧编码模式（v1 仅 VERBATIM；M1 起扩展 FIXED/LPC）。
pub(all) enum SubframeMode {
  Verbatim
}

///|
/// 写 VERBATIM 子帧：samples[from, from+len) 每样本 bps 位原值。
pub fn encode_verbatim(w : BitWriter, samples : Array[Int32], from : Int, len : Int, bps : Int) -> Unit {
  w.write_bits(0U, 1) // 零填充位
  w.write_bits(1U, 6) // 类型码 000001 = VERBATIM
  w.write_bits(0U, 1) // wasted-bits 标志：0 = 无
  let mask = if bps == 32 { 0xFFFFFFFFU } else { (1U << bps) - 1U }
  for i = from; i < from + len; i = i + 1 {
    w.write_bits(samples[i].reinterpret_as_uint() & mask, bps)
  }
}
