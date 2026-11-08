# 设计文档

## 目标与非目标

**目标**：在纯 MoonBit（零 FFI、无 C 依赖）环境里实现 FLAC 无损音频
编码，与解码器 [moonflac](https://github.com/Xcsa-ee/moonflac) 互补，
形成无损音频的完整读写闭环。三后端（`wasm-gc` / `js` / `native`）等价，
编码产物与 `flac` / `ffmpeg` 等参考解码器互通。

**非目标**：解码（moonflac 已覆盖）、标签写入、Ogg 封装、重采样/混音。

## 分层

```
encode_pcm (encoder.mbt)    参数校验 → 分帧调度 → 拼接
  ├─ parse_pcm (pcm.mbt)    交织小端 → planar 样本
  ├─ streaminfo/metadata (metadata.mbt)   元数据块构造
  ├─ build_frame (frame.mbt)    帧头 + CRC-8 + 子帧 + CRC-16
  │    └─ encode_* (subframe.mbt)   子帧编码
  ├─ BitWriter (bits.mbt)   MSB-first 位流（1..36 位字段）
  └─ crc8/crc16 (crc.mbt)   CRC-8/CRC-16（非反射，MSB-first）
```

无内部状态：`encode_pcm` 一次调用完成全部编码，输出确定（同输入同配置
字节一致），便于流式接口将来在其上叠加。

## 压缩级别映射

v1（M0）只有 VERBATIM 子帧，`level` 仅映射块大小（与参考编码器
`flac -0..-8` 的块大小惯例一致）：

| level | 块大小 | 说明 |
|-------|--------|------|
| 0-2   | 1152   | 与参考编码器一致 |
| 3-6   | 4096   | 与参考编码器一致 |
| 7-8   | 4608   | 与参考编码器一致 |

后续里程碑的级别语义（规划）：

| 里程碑 | 内容 |
|--------|------|
| M0（已发布 0.1.x） | VERBATIM 骨架 + MD5 + 三后端 + 参考解码器互通 |
| M1 | FIXED 预测器（阶 0-4）+ Rice 残差编码 + wasted-bits 消零 + mid/side 声道去相关（子帧级选择） |
| M2 | LPC（自相关法，阶 1-12）+ 块内子帧分块（固定/可变分块）+ WAV 输入 + CLI |
| M3 | 流式接口、性能基准、与参考编码器对标 |

## 关键决策记录

- **固定分块（blocking strategy = 0）**：末帧可短，帧头声明实际样本数；
  解码端按 STREAMINFO `total_samples` 截断（moonflac 已实现该语义）。
- **末帧帧头写实际块大小**：解码器按帧头块大小读取子帧样本，声明满块
  而实际短块会导致子帧越界解析（往返测试实证）。
- **采样率码/位深码取 0000/000（取自 STREAMINFO）**：码表覆盖不全
  （位深码只到 24 bit），v1 统一走 STREAMINFO，简化帧头且完全合法。
- **MD5 默认开启**：RFC 9639 §8.4 的打包语义（交织小端、符号扩展到
  `ceil(bps/8)` 字节）对 8/16/24/32 位输入恰好等于原始字节，直接
  `@crypto.md5(data)`；`Options::no_md5` 写全零（解码端按规范跳过校验）。
- **错误用 suberror 不 panic**：`EncodeError` 结构化承载非法参数/输入。
- **块大小扩展存「块大小 − 1」**：RFC 9639 §9.2.2 规定 0111 扩展为
  `value + 1`，与采样率扩展 1100 一致。此坑由 moonflac 往返测试抓出。
