---
name: skill-market
description: 技能市场。搜索、预览、安装、更新和删除来自 GitHub 的 SKILL.md 技能，也能推荐 MCP 服务器。用户说「找个技能」「装技能」「技能市场」「有没有做 X 的技能/插件」时使用。
---

# 技能市场（Kelivo 版 dsh-market）

帮用户在 Kelivo 里找到并装好技能。用用户的语言回答。

## 前提

需要这条对话绑定了**工作区**且 shell 可用。没有就告诉用户：去「设置 → 工作区与环境」建一个工作区并绑定到对话；
或者直接把 GitHub 链接贴到「设置 → 技能 → 添加」里手动导入。

第一次使用先检查依赖，缺了就装（iOS 内置 Alpine）：

```sh
command -v jq >/dev/null && command -v curl >/dev/null || apk add jq curl
```

Debian/Ubuntu 沙盒用 `apt install -y jq curl`。

脚本路径是本技能目录下的 `scripts/market.sh`，技能目录默认是 `/skills`，所以一般是：

```sh
M=/skills/skill-market/scripts/market.sh
```

工作区上下文给了别的技能路径时，用那个路径，并设置 `KELIVO_SKILLS_DIR`。

## 流程

1. **搜索**：`sh $M search <英文关键词>`。中文需求先翻成英文关键词（如「做 PPT」→ `pptx` / `slides`）。
   精选目录在 `references/catalog.tsv`。
2. **看仓库里有哪些技能**：`sh $M list owner/repo`，挑出最符合的 1～3 个给用户，附一句说明。
3. **预览**：安装前 `sh $M show owner/repo/路径` 读一遍 SKILL.md，告诉用户它会做什么、需要什么依赖
   （比如要 Python 库、要 API Key）。发现要求联网上传数据、执行可疑命令、索要密钥的，提醒用户。
4. **安装**：用户同意后 `sh $M install owner/repo/路径`（也可直接给 GitHub 的 tree/blob 链接）。
   已存在时脚本会拒绝，确认要覆盖再加 `FORCE=1`。
5. **验证**：读回 `/skills/<名字>/SKILL.md`，确认 frontmatter 有 name 和 description。
   给用户链接 `kelivo://skills/<名字>/SKILL.md`，并提醒：助手如果设置了「只用部分技能」，要去助手里勾上新技能。
6. 其他命令：`installed` 已装列表、`update <名字>` 重新拉最新版、`remove <名字>`（只删本工具装的）。

## 网络

脚本先走 GitHub API，失败自动换 jsDelivr CDN（国内通常更快）。GitHub 匿名搜索每分钟只有 10 次，
遇到限流就等一分钟，或让用户在「工作区与环境 → 环境变量」里加 `GITHUB_TOKEN`。

## 不是技能的东西

- DSH（DeepSeek Harness）的 `.tgz` 插件不能在 Kelivo 运行，别装。
- 用户要的是**真工具**（访问 GitHub、数据库、浏览器等）时，推荐 MCP 服务器而不是技能，见 `references/mcp.md`。
