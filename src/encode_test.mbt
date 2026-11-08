// encode_test.mbt
//
// 端到端往返：编码后用 moonflac 解码逐样本比对。moonflac 在
// STREAMINFO 有 MD5 时校验 MD5（RFC 9639 §8.4 打包，其打包方式
// 已与 ffmpeg 交叉验证），所以往返通过同时证明 MD5 正确。

///|
/// planar 样本 → 交织小端 PCM 字节（b ∈ {8,16,24,32}，每样本 b/8 字节）。
fn pack_pcm(samples : Array[Array[Int32]], bps : Int) -> Bytes {
  let b = @buffer.Buffer()
  let frames = samples[0].length()
  for f = 0; f < frames; f = f + 1 {
    for c = 0; c < samples.length(); c = c + 1 {
      let v = samples[c][f]
      for k = 0; k < bps / 8; k = k + 1 {
        b.write_byte(((v >> (8 * k)) & 0xFF).to_byte())
      }
    }
  }
  b.to_bytes()
}

///|
/// 编码 → moonflac 解码 → 逐样本比对。辅助函数内用 abort 报差异
/// （assert_eq 带 raise 签名，不能出现在非 raise 函数里）。
fn roundtrip_check(
  samples : Array[Array[Int32]],
  bps : Int,
  sample_rate : Int,
  block_size : Int,
) -> Unit {
  let pcm = pack_pcm(samples, bps)
  let flac = try {
    encode_pcm(pcm, samples.length(), bps, sample_rate, Options::new(5, block_size))
  } catch {
    e => abort("encode failed: \{e.to_message()}")
  }
  let decoded = try {
    @moonflac.decode(flac)
  } catch {
    // FlacError 无 Show；按变体分类报错便于定位
    @moonflac.FlacError::Truncated(offset=o, need=n, actual=a) => abort("decode Truncated: offset=\{o} need=\{n} actual=\{a} flac_len=\{flac.length()}")
    @moonflac.FlacError::NotFlac => abort("decode NotFlac")
    @moonflac.FlacError::BadMetadata(..) => abort("decode BadMetadata")
    @moonflac.FlacError::BadFrameHeader(..) => abort("decode BadFrameHeader")
    @moonflac.FlacError::BadCrc(..) => abort("decode BadCrc")
    @moonflac.FlacError::BadSubframe(..) => abort("decode BadSubframe")
    @moonflac.FlacError::BadResidual(..) => abort("decode BadResidual")
    @moonflac.FlacError::Md5Mismatch(..) => abort("decode Md5Mismatch")
  }
  if decoded.channels.length() != samples.length() {
    abort(
      "channel mismatch: got \{decoded.channels.length()}, want \{samples.length()}",
    )
  }
  for c = 0; c < samples.length(); c = c + 1 {
    if decoded.channels[c].length() != samples[c].length() {
      abort(
        "sample count mismatch at ch \{c}: got \{decoded.channels[c].length()}, want \{samples[c].length()}",
      )
    }
    for i = 0; i < samples[c].length(); i = i + 1 {
      if decoded.channels[c][i] != samples[c][i] {
        abort(
          "sample mismatch at ch \{c}[i \{i}]: got \{decoded.channels[c][i]}, want \{samples[c][i]}",
        )
      }
    }
  }
}

///|
/// 确定性伪随机信号（LCG），幅度覆盖 [-2^(bits-1), 2^(bits-1))。
/// bits=32 时用 31 位 LCG 输出平移（1<<31 会溢出 Int32）。
fn make_signal(n : Int, seed : Int, bits : Int) -> Array[Int32] {
  let s : Array[Int32] = []
  let mut x = seed
  for _i = 0; _i < n; _i = _i + 1 {
    x = (x * 1103515245 + 12345) & 0x7FFFFFFF
    if bits == 32 {
      s.push(x - (1 << 31)) // 1<<31 溢出为 Int32 最小值的位型
    } else {
      let half = 1 << (bits - 1)
      s.push(x % (2 * half) - half)
    }
  }
  s
}

test "roundtrip mono 16-bit multi-block with short last frame" {
  // 2000 样本 / 块 1152 → 2 帧：满帧 + 末帧 848（走 16 位块大小扩展）
  let ch = make_signal(2000, 42, 16)
  roundtrip_check([ch], 16, 44100, 1152)
}

test "roundtrip 8-bit mono silence" {
  let ch : Array[Int32] = Array::make(300, 0)
  roundtrip_check([ch], 8, 8000, 192)
}

test "roundtrip 24-bit stereo single short frame" {
  // 2500 样本 / 块 4096 → 单帧短块（2500 也在 16 位扩展路径）
  let left = make_signal(2500, 7, 24)
  let right = make_signal(2500, 99, 24)
  roundtrip_check([left, right], 24, 48000, 4096)
}

test "roundtrip 32-bit mono exact multiple" {
  // 2304 = 2 × 1152，无短帧；32 位全幅值
  let ch = make_signal(2304, 12345, 32)
  roundtrip_check([ch], 32, 96000, 1152)
}

test "roundtrip md5 disabled still decodes" {
  // md5=false 时 STREAMINFO 的 MD5 全零，moonflac 跳过校验
  let ch = make_signal(500, 1, 16)
  let pcm = pack_pcm([ch], 16)
  let flac = encode_pcm(pcm, 1, 16, 44100, Options::no_md5(5, 1152))
  let decoded = try {
    @moonflac.decode(flac)
  } catch {
    _e => abort("decode failed")
  }
  assert_eq(decoded.channels[0].length(), 500)
  assert_eq(decoded.channels[0][0], ch[0])
  assert_eq(decoded.channels[0][499], ch[499])
}

test "encode is deterministic" {
  let ch = make_signal(1000, 5, 16)
  let pcm = pack_pcm([ch], 16)
  let a = encode_pcm(pcm, 1, 16, 44100, Options::new(5, 1152))
  let b = encode_pcm(pcm, 1, 16, 44100, Options::new(5, 1152))
  assert_eq(a.length(), b.length())
  for i = 0; i < a.length(); i = i + 1 {
    assert_eq(a.unsafe_get(i), b.unsafe_get(i))
  }
}

test "encode rejects invalid parameters" {
  // bps 非法
  try {
    let _ = encode_pcm(b"", 1, 12, 44100, Options::new(5, 0))
    abort("expected InvalidBitsPerSample")
  } catch {
    EncodeError::InvalidBitsPerSample => ()
    _ => abort("wrong error")
  }
  // 声道数非法
  try {
    let _ = encode_pcm(b"", 0, 16, 44100, Options::new(5, 0))
    abort("expected InvalidChannels")
  } catch {
    EncodeError::InvalidChannels => ()
    _ => abort("wrong error")
  }
  try {
    let _ = encode_pcm(b"", 9, 16, 44100, Options::new(5, 0))
    abort("expected InvalidChannels")
  } catch {
    EncodeError::InvalidChannels => ()
    _ => abort("wrong error")
  }
  // 采样率非法
  try {
    let _ = encode_pcm(b"", 1, 16, 0, Options::new(5, 0))
    abort("expected InvalidSampleRate")
  } catch {
    EncodeError::InvalidSampleRate => ()
    _ => abort("wrong error")
  }
  try {
    let _ = encode_pcm(b"", 1, 16, 655351, Options::new(5, 0))
    abort("expected InvalidSampleRate")
  } catch {
    EncodeError::InvalidSampleRate => ()
    _ => abort("wrong error")
  }
  // 块大小非法
  try {
    let _ = encode_pcm(b"", 1, 16, 44100, Options::new(5, 15))
    abort("expected InvalidBlockSize")
  } catch {
    EncodeError::InvalidBlockSize => ()
    _ => abort("wrong error")
  }
  try {
    let _ = encode_pcm(b"", 1, 16, 44100, Options::new(5, 70000))
    abort("expected InvalidBlockSize")
  } catch {
    EncodeError::InvalidBlockSize => ()
    _ => abort("wrong error")
  }
}

test "encode empty input is valid stream" {
  let flac = encode_pcm(b"", 2, 16, 44100, Options::new(5, 1152))
  let decoded = try {
    @moonflac.decode(flac)
  } catch {
    _e => abort("decode failed")
  }
  assert_eq(decoded.channels.length(), 2)
  assert_eq(decoded.channels[0].length(), 0)
}
