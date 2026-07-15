---
name: "GS: CSO"
description: Security audit checklist for sensitive changes
category: Workflow
tags: [workflow, gstack-bridge, security]
---

Run a security audit checklist against the current branch's changes.
Check each item and report a clear finding for each (nothing found /
found: <what>), not a vague "looks fine":

1. **密钥/凭证**:diff 里有没有新增的 API key、token、密码、连接串等
   硬编码内容?
2. **权限变更**:有没有修改访问控制、认证逻辑、角色权限的代码?如果
   有,逻辑是变严格还是变宽松?
3. **依赖**:本次改动有没有新增第三方依赖?是否有已知漏洞(可用
   `npm audit` 或等价工具核实)?
4. **冻结区**:本次改动有没有触碰 `.claude/frozen-paths.txt` 里声明
   的路径?如果 `hooks/freeze-gate.sh` 正常工作,这类改动本应被拦截
   ——如果发现绕过了,单独指出。
