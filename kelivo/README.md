# Kelivo 版技能市场

`dsh-market` 是 DeepSeek Harness 的插件市场，代码跑在 DSH 里，Kelivo 用不了。
这个目录把同样的想法做成一个 **Kelivo 技能**：让 Kelivo 里的模型帮你搜索、预览、安装、更新、删除 GitHub 上的 SKILL.md 技能，并推荐 MCP 服务器。

## 安装到 Kelivo

**方法一（最简单）**：Kelivo「设置 → 技能 → 添加」，选 GitHub 链接，填：

```
https://github.com/zmc881317/dsh-market/tree/kelivo/kelivo/skill-market
```

**方法二**：下载这个目录打成 zip，在「设置 → 技能」导入 .zip。

## 使用

1. 「设置 → 工作区与环境」建一个工作区，绑定到对话（脚本需要 shell）。
2. 确认技能已启用；助手如果只开了部分技能，把 `skill-market` 勾上。
3. 直接说：「帮我找个做 PPT 的技能」「装 anthropics/skills 里的 pdf」「我装了哪些技能」。

也可以在 Kelivo 终端里手动用：

```sh
apk add jq curl          # 第一次
M=/skills/skill-market/scripts/market.sh
sh $M search pdf
sh $M list anthropics/skills
sh $M install anthropics/skills/skills/pdf
sh $M installed
sh $M update pdf
sh $M remove pdf
```

## 说明

- 先走 GitHub API，失败自动换 jsDelivr CDN。
- 匿名 GitHub 搜索限额低，可在环境变量里设 `GITHUB_TOKEN`。
- 只删除用本工具装的技能（有 `.market-source` 记录的），内置和手动导入的不碰。
- DSH 的 .tgz 插件不能在 Kelivo 用。
