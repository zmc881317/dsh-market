# 给 Kelivo 找 MCP 服务器

MCP 是真工具，技能只是说明书。用户要「让模型能操作某个服务」时推荐 MCP。

## 去哪找

- https://mcp.so/servers —— 最大的社区目录
- https://smithery.ai —— 很多服务器有托管的远程地址
- https://github.com/modelcontextprotocol/servers —— 官方参考实现
- https://github.com/punkpeye/awesome-mcp-servers —— 精选列表

## 怎么装进 Kelivo

「设置 → MCP → 添加」（或长按输入栏的锤子图标）。

- **Streamable HTTP / SSE**：填服务器地址，需要登录的走 OAuth。手机上优先选这种。
- **STDIO**：填启动命令（如 `npx -y @modelcontextprotocol/server-xxx`）。手机上跑在沙盒里，
  需要先在沙盒装好 Node.js / Python，较重的服务器在 iPhone 上可能跑不动。
- 也可以粘贴 JSON 配置导入（Claude Desktop 的 `mcpServers` 格式）。

装好后在助手或对话里打开该服务器，工具权限建议选「每次询问」。只连信任的服务器。
