# 玉磬 moonflac-enc

纯 MoonBit 实现的 **FLAC 无损音频编码器**：零 FFI、不依赖任何 C 库或
系统编解码器，可编译到 `wasm-gc` / `js` / `native` 三后端。

与解码器 [Xcsa-ee/moonflac](https://mooncakes.io/docs/Xcsa-ee/moonflac)
互补：moonflac 只解码，本项目只编码。两者组合即可在纯 MoonBit
（含浏览器 wasm）环境中完成无损音频的完整读写闭环——例如网页端录音
无损保存、媒体工具链、嵌入式音频采集。

> 状态：M0 开发中（VERBATIM 骨架），尚未发布。

## 安装

```bash
moon add QYF795/moonflac-enc
```

## 快速开始

```moonbit
import {
  "QYF795/moonflac-enc",
  "moonbitlang/x/fs",
}

fn main raise {
  // 44.1 kHz / 16 位 / 单声道交织小端 PCM（FLAC 惯例）
  let pcm : Bytes = @fs.read_file_to_bytes("input.pcm")
  let flac : Bytes = @moonflacenc.encode_pcm(pcm, channels=1, bps=16, sample_rate=44100)
  @fs.write_bytes_to_file("output.flac", flac)
}
```

编码产物可用 moonflac 解码回 PCM，或由 `flac` / `ffmpeg` 等参考解码器
直接验证。

## 支持范围

- 位深 8/16/24/32 bit，声道 1-8，采样率 1 Hz – 655350 Hz
- 固定分块 + VERBATIM 子帧（M0；FIXED/LPC 预测器按里程碑推进，见
  [docs/design.md](docs/design.md) 的级别映射表）
- STREAMINFO 全字段 + MD5 完整性签名（RFC 9639 §8.4 语义）
- 确定性输出：同输入同配置字节一致

## 明确不做

- 解码（请用 moonflac）
- 标签（Vorbis Comment/PICTURE）写入、Ogg 封装
- 重采样、混音、音频设备输出

## 验证

- 单元测试：`moon test --target js`（wasm-gc 同）
- 往返验证：编码产物由 moonflac 解码，逐样本比对
- 参考解码器交叉验证（CI）：`flac -t` + `ffmpeg` 交叉解码逐字节比对
- 详见 [docs/acceptance.md](docs/acceptance.md)

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

Apache-2.0
