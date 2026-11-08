// pcm_test.mbt
//
// PCM 解析验证：交织小端 → planar 的展开顺序、各位深的符号扩展、
// 以及尺寸不整除时 raise InvalidInputSize（绝不 panic）。

test "parse 16-bit stereo interleaved LE" {
  let data = b"\x34\x12\x78\x56\xCD\xAB\xEF\xBE"
  let planar = parse_pcm(data, 2, 16)
  assert_eq(planar[0][0], 0x1234)
  assert_eq(planar[0][1], -21555) // 0xABCD 符号扩展
  assert_eq(planar[1][0], 0x5678)
  assert_eq(planar[1][1], -16657) // 0xBEEF 符号扩展
}

test "parse 8-bit signed" {
  let planar = parse_pcm(b"\xFF\x80\x7F\x00", 1, 8)
  assert_eq(planar[0][0], -1)
  assert_eq(planar[0][1], -128)
  assert_eq(planar[0][2], 127)
  assert_eq(planar[0][3], 0)
}

test "parse 24-bit sign extension" {
  let planar = parse_pcm(b"\x00\x80\xFF", 1, 24)
  assert_eq(planar[0][0], -32768)
  let planar2 = parse_pcm(b"\xFF\xFF\x7F", 1, 24)
  assert_eq(planar2[0][0], 8388607)
}

test "parse 32-bit sign extension" {
  let planar = parse_pcm(b"\xFF\xFF\xFF\x7F", 1, 32)
  assert_eq(planar[0][0], 2147483647)
  let planar2 = parse_pcm(b"\x00\x00\x00\x80", 1, 32)
  assert_eq(planar2[0][0], -2147483648)
}

test "parse rejects non-divisible size" {
  try {
    let _ = parse_pcm(b"\x00\x01\x02", 1, 16)
    abort("expected InvalidInputSize")
  } catch {
    EncodeError::InvalidInputSize => ()
    _ => abort("wrong error type")
  }
}

test "parse accepts empty input" {
  let planar = parse_pcm(b"", 2, 24)
  assert_eq(planar.length(), 2)
  assert_eq(planar[0].length(), 0)
  assert_eq(planar[1].length(), 0)
}
