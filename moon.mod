name = "QYF795/moonflac-enc"

version = "0.1.0"

description = "玉磬：纯 MoonBit FLAC 无损音频编码器（零 FFI，native/wasm-gc/js 三后端）。"

readme = "README.md"

repository = "https://github.com/QYF795/moonflac-enc"

license = "Apache-2.0"

keywords = [ "audio", "flac", "codec", "lossless", "encoder" ]

source = "src"

warnings = "-test_unqualified_package"

import {
  "moonbitlang/x@0.5.7",
  "Xcsa-ee/moonflac@0.3.4",
}
