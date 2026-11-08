# 验收清单

每项在发布前必须通过；「验证方式」指明由哪些测试/CI 步骤保证。

| # | 验收项 | 验证方式 |
|---|--------|----------|
| 1 | 参数非法（bps/声道/采样率/块大小）raise EncodeError，不 panic | `encode_test.mbt` 6 类非法参数 |
| 2 | 输入尺寸不整除声道×字节深 raise InvalidInputSize | `pcm_test.mbt` |
| 3 | STREAMINFO 34 字节字段位排布正确 | `metadata_test.mbt` 位读取回读 + 手工推演黄金向量 |
| 4 | 帧头字节布局（同步码/块码/声道/UTF-8 帧号/16 位扩展）正确 | `frame_test.mbt` |
| 5 | CRC-8 覆盖帧头、CRC-16 覆盖帧体 | `frame_test.mbt` + `crc_test.mbt` 标准向量 |
| 6 | 块大小扩展存「−1」 | `frame_test.mbt`（999=0x03E7）+ 往返 |
| 7 | 8/16/24/32 位深编码 → moonflac 解码逐样本一致 | `encode_test.mbt` 4 个往返 |
| 8 | 多帧 + 末帧短块正确截断 | `encode_test.mbt` 16 位 2000/1152 双帧 |
| 9 | MD5 与参考语义一致 | 往返测试（moonflac 校验 MD5，其打包已与 ffmpeg 交叉验证） |
| 10 | md5 关闭时写全零、可被解码 | `encode_test.mbt` md5-disabled |
| 11 | 确定性：同输入同配置字节一致 | `encode_test.mbt` determinism |
| 12 | 参考解码器互通：`flac -t` 通过 + ffmpeg 交叉解码逐字节还原 | CI conformance job |
| 13 | 三后端（js/wasm-gc/native）测试全绿 + `--deny-warn` 零警告 | CI matrix + check |
