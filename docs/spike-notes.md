# Spike 笔记（调研/实测记录）

## 2026-11 排雷：moonbit 工具链（moon 0.1.20261012，core 0.10.15）

- 方法语法：`fn Type::meth(self : Type, ...)`；旧式 `fn meth(self : Type)`
  已 deprecated（--deny-warn 会报错）。
- 错误类型用 `pub suberror E { ... }`（enum 不能直接 raise），
  catch 分支按变体模式匹配，须穷举（多了 catch-all 报 unreachable）。
- `assert_eq` 带 raise 签名，不能出现在非 raise 的辅助函数里；
  辅助函数内用 `if ... { abort(...) }` 报差异。
- 测试文件是隐式 blackbox test 包（moon.mod 需
  `warnings = "-test_unqualified_package"`）。
- 包别名：`import { "pkg/name" @alias }`（moon.pkg），包名带连字符时
  默认别名非法，必须显式别名。
- `Int.to_float()`/`to_double()` 已弃用 → `Float::from_int` /
  `Double::from_int`。
- **`Buffer::write_string` 写 UTF-16LE 且已 deprecated**——二进制格式的
  魔数必须 `write_bytes`（本仓库魔数写入曾踩）。
- js 后端 UInt 移位按 32 位取模（core 无原子/锁原语，2026-11 实测），
  `write_bits` 对移位 ≥32 有守卫。
- 数组是引用类型，绑定无需 `mut` 也能 push；`let mut` 会触发
  unused_mut。
- `1 << 31` 溢出为 Int32 最小值位型，`2147483648` 字面量直接报错。

## CRC 验证向量

- CRC-8（poly 0x07）：b"123456789" → `0xF4`，b"\x80" → `0x89`
- CRC-16/BUYPASS（poly 0x8005，非反射）：b"123456789" → `0xFEE8`
  （⚠️ 不是 0xBB3D——那是反射版 CRC-16/ARC 的常见向量）
- 手算向量必须逐位重推：曾按反射算法/记忆值写错 4 个期望值，
  代码本身是对的。

## mid/side 与 wasted-bits 语义（M1 预告）

- mid/side（声道分配码 8/9）：mid = (l+r)>>1，side = l−r；side 子帧
  类型按「位深 + 1」解释（side 可能超出原位深一位）。
- wasted-bits：子帧头标志位为 1 时后续存 k−1（k≥1，每样本有效位
  右移 k 位后编码）；子帧类型码按右移后的位深解释。M1 引入，需在
  帧头位深与子帧实际位深间换算。

## MD5 打包（RFC 9639 §8.4）

对 8/16/24/32 位输入，MD5 输入 = 原始交织小端字节（符号扩展后
`ceil(bps/8) = bps/8` 字节）。对 4/12/20 位等非字节对齐位深才需要
逐样本紧凑打包——v1 不支持这些位深，moonflac 已覆盖其解码侧校验。

## 块大小扩展 −1（实测排雷）

16 位扩展存「块大小 − 1」。写原值 → 解码端（moonflac）读成 +1 →
子帧越界 → 后续帧同步错位 → 表现为 Truncated（字节深处）或
BadResidual（位错位后类型码误读）。修复后往返全绿。

## 参考编码器块大小惯例

flac -0..-2 → 1152；-3..-6 → 4096；-7..-8 → 4608。全部命中表码。
（levels 语义详见 design.md 映射表。）
