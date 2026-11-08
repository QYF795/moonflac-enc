// encoder.mbt
//
// 顶层编码入口：PCM 字节流 → 完整 FLAC 字节流。
// v1 = verbatim 骨架：fLaC 魔数 + STREAMINFO（唯一元数据块，is_last=1）
// + 固定分块帧序列。末帧按实际余量写短块（帧头块大小声明实际值，
// 与 libFLAC 参考编码器一致；STREAMINFO min/max 仍为满块大小）。
// MD5 默认计算（RFC 9639 §8.4：交织小端、符号扩展到整字节——
// 8/16/24/32 位输入的原始字节恰好就是该表示），可关闭。

///|
/// 编码选项。v1 只有 block_size 与 md5 开关；
/// level 按参考编码器惯例映射块大小（校验用），M1 起影响子帧策略。
pub struct Options {
  level : Int
  block_size : Int
  md5 : Bool
}

///|
/// level → 默认块大小（与 flac 参考编码器 -0..-8 的映射一致，
/// 全部命中块大小表码，无需 16 位扩展）。
pub fn level_block_size(level : Int) -> Int {
  if level <= 2 {
    1152
  } else if level <= 6 {
    4096
  } else {
    4608
  }
}

///|
/// 新建选项。block_size = 0 时按 level 查表。
pub fn Options::new(level : Int, block_size : Int) -> Options {
  let bs = if block_size == 0 { level_block_size(level) } else { block_size }
  { level: level, block_size: bs, md5: true }
}

///|
/// 关闭 MD5 校验和（总长度未知或无需校验的场合）。
pub fn Options::no_md5(level : Int, block_size : Int) -> Options {
  let bs = if block_size == 0 { level_block_size(level) } else { block_size }
  { level: level, block_size: bs, md5: false }
}

///|
/// 把交织小端 PCM 编码为完整 FLAC 字节流。参数非法或输入尺寸
/// 不整除时 raise EncodeError，绝不 panic。
pub fn encode_pcm(
  data : Bytes,
  channels : Int,
  bps : Int,
  sample_rate : Int,
  opts : Options,
) -> Bytes raise EncodeError {
  if bps != 8 && bps != 16 && bps != 24 && bps != 32 {
    raise InvalidBitsPerSample
  }
  if channels < 1 || channels > 8 {
    raise InvalidChannels
  }
  if sample_rate < 1 || sample_rate > 655350 {
    raise InvalidSampleRate
  }
  if opts.block_size < 16 || opts.block_size > 65535 {
    raise InvalidBlockSize
  }
  let planar = parse_pcm(data, channels, bps)
  let total = planar[0].length()
  let md5 : FixedArray[Byte] = if opts.md5 {
    @crypto.md5(data)
  } else {
    FixedArray::make(16, (0).to_byte())
  }
  let out = @buffer.Buffer()
  out.write_bytes(b"fLaC") // 魔数按原始字节写（write_string 是 UTF-16，不可用）
  let info = streaminfo_payload(
    opts.block_size,
    sample_rate,
    channels,
    bps,
    total.reinterpret_as_uint(),
    md5,
  )
  out.write_bytes(metadata_block(0, true, info))
  let mut from = 0
  let mut fnr = 0U
  while from < total {
    let len = if opts.block_size < total - from {
      opts.block_size
    } else {
      total - from
    }
    // 帧头块大小声明本帧实际样本数：末帧短块必须写实际余量
    //（解码器按帧头块大小读取子帧），非末帧 len == opts.block_size
    out.write_bytes(
      build_frame(len, channels, bps, fnr, planar, from, len, Verbatim),
    )
    from = from + opts.block_size
    fnr = fnr + 1
  }
  out.to_bytes()
}
