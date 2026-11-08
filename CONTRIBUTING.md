# 贡献指南

感谢你对 moonflac-enc 的关注！本项目是 MoonBit 语言生态下的纯
MoonBit FLAC 无损音频编码器，欢迎任何形式的贡献：bug 报告、文档
修正、代码、新后端适配。

## 环境准备

- [moon](https://www.moonbitlang.com/download/) ≥ 0.1.2026（moon.mod 为 TOML 格式）
- 本机测试需要 js 与 wasm-gc 后端（随 moon 发行）；native 后端额外需要
  C 编译器（没有也无妨，本机验证以 js + wasm-gc 双后端为准）

```bash
git clone https://github.com/QYF795/moonflac-enc
cd moonflac-enc
moon test --target js             # 首次运行自动解析依赖
```

## 构建与测试

```bash
moon check                       # 静态检查（必须零警告）
moon test                        # js + wasm-gc 双后端全量测试
moon test --target native        # 有 C 编译器时
moon run src/demo --target js    # 生成 demo.flac / demo.pcm
```

测试布局：

- `src/*_test.mbt` — 黑盒测试（blackbox 包），只经公开 API 访问库；
  需要测试私有行为时，在测试内写局部 helper。
- 往返测试把 moonflac（解码器）作为 dev 依赖：编码产物必须能被
  生态内另一实现逐样本还原——互操作即验证。
- CI 的 conformance 任务另用参考解码器（`flac -t`、ffmpeg）交叉验证。

## 提交规范

- 提交信息用 Conventional Commits（`feat:` / `fix:` / `docs:` / `test:` /
  `ci:` / `refactor:`），主体说明动机与影响面。
- 每个 PR ≤ 500 行，单主题；PR 描述末尾注明
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`。
- 涉及码流格式的改动必须同步更新 `docs/format.md`，并在
  `docs/acceptance.md` 的对应验收项上补测试证明。
- 推送前要求：`moon check` 零警告 + `moon test` 双后端全绿。
- 改动触及编码热路径时跑一次 `moon bench` 确认没有数量级退化，
  数字对比 `docs/bench.md`。

## 代码风格

- 每文件头部一段注释说明该模块在整体中的位置。
- 位序敏感逻辑（MSB-first、字段位宽）就地注释，注明
  "为什么必须这样"，而不是复述代码。
- 命名沿用项目惯例：`snake_case` 函数、`CamelCase` 类型、公开 API 加
  `///` 文档注释。

## 设计讨论

架构决策记录在 `docs/design.md` §6；码流格式的唯一权威是
`docs/format.md`（FLAC 规范子集 + 本项目的编码决策）。任何
"为什么这么设计"的问题先查这两份文档，找不到答案再开 issue——
那通常意味着文档该补了。
