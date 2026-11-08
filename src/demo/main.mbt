// main.mbt
//
// 编码演示：生成 440Hz 正弦（44100Hz/16bit/单声道/2000 样本），
// 编码为 FLAC（块 1152 → 2 帧：满帧 + 末帧短块 848 样本，短块走
// 16 位块大小扩展），再用 moonflac 解码回 WAV。
// 产物：demo.pcm / demo.flac / demo.dec.wav。
// CI 用 flac -t 与 ffmpeg 交叉解码验证 demo.flac 与真实工具链互通。

fn main {
  let sample_rate = 44100
  let bps = 16
  let channels = 1
  let n = 2000
  let freq = 440.0
  let ch : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    let t = Double::from_int(i) / Double::from_int(sample_rate)
    let v = @math.sin(6.28318530718 * freq * t) * 0.5 * 32767.0
    ch.push(v.to_int())
  }
  // 交织小端 PCM
  let pcm = @buffer.Buffer()
  for i = 0; i < n; i = i + 1 {
    let v = ch[i]
    pcm.write_byte((v & 0xFF).to_byte())
    pcm.write_byte(((v >> 8) & 0xFF).to_byte())
  }
  let flac = try {
    @enc.encode_pcm(pcm.to_bytes(), channels, bps, sample_rate, @enc.Options::new(5, 1152))
  } catch {
    e => abort("encode failed: \{e.to_message()}")
  }
  let decoded = try {
    @moonflac.decode(flac)
  } catch {
    _e => abort("self-decode failed")
  }
  let wav = @moonflac.wav_encode(decoded.channels, bps, sample_rate)
  try {
    @fs.write_bytes_to_file("demo.pcm", pcm.to_bytes())
    @fs.write_bytes_to_file("demo.flac", flac)
    @fs.write_bytes_to_file("demo.dec.wav", wav)
  } catch {
    _e => abort("write failed")
  }
  println("pcm: \{pcm.length()} bytes")
  println("flac: \{flac.length()} bytes (verbatim 无压缩，供结构验证)")
  println("decoded wav: \{wav.length()} bytes")
  println(
    "channels: \{decoded.channels.length()}, samples: \{decoded.channels[0].length()}",
  )
  println(
    "sine[0..3]: \{ch[0]}, \{ch[1]}, \{ch[2]} | decoded[0..3]: \{decoded.channels[0][0]}, \{decoded.channels[0][1]}, \{decoded.channels[0][2]}",
  )
  // moonflac 已验证 MD5；这里再比对样本值作为第二重保障
  let mut ok = true
  for i = 0; i < n; i = i + 1 {
    if decoded.channels[0][i] != ch[i] {
      ok = false
    }
  }
  println(if ok { "roundtrip: OK" } else { "roundtrip: MISMATCH" })
}
