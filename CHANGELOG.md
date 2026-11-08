# Changelog

本项目的所有显著变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

### Added

- M0 骨架：VERBATIM 子帧编码 `encode_pcm`（固定分块、末帧短块、
  STREAMINFO 全字段、MD5 校验和、`Options` 含 md5 开关）。
- 基础件：MSB-first 位写入器、CRC-8/CRC-16（非反射）、PCM 解析
  （8/16/24/32 位交织小端 → planar）、帧组装（CRC-8 帧头 +
  CRC-16 帧体 + UTF-8 帧号 + 16 位块大小扩展）。
- 结构化错误 `EncodeError`（suberror，非法参数/输入不 panic）。
- 往返测试套件：编码产物由 moonflac 解码逐样本比对（含 MD5 校验），
  js/wasm-gc 双后端 36/36。
- demo：正弦 PCM → demo.flac → moonflac 自解码（`src/demo`）。
- CI：三后端测试矩阵 + `--deny-warn` + flac/ffmpeg 参考解码器交叉验证。
- 文档：design / format / acceptance（13 项验收）/ spike-notes。
