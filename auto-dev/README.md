# Auto-Dev 全链路自动化开发

> 全自动开发流水线 — 输入 TFS 工作项 ID，从需求分析到代码提交 PR 一站式完成。

## 功能特性

- **全链路自动化**：PM 分析 → 编码 → Git 提交 → TFS PR 创建 + 自动评审，无需人工干预
- **多技能路由**：根据标签自动路由到 backend-dev、frontend-dev、rdf-dev
- **灵活开发模式**：默认直接在源仓库开发，可选 worktree 隔离模式实现多仓库并行开发
- **批量处理**：支持单工作项或多需求号批量处理（如 "自动开发 1506090 1506091 1506092"）
- **企微通知**：处理完成后自动推送结果到企业微信群

## 快速开始

### 1. 触发方式

在 Claude Code 中输入：

```
自动开发 1506090
全自动开发需求 1506090
```

或任何包含以下关键词的指令：

- `自动开发` + 需求号
- `auto-dev` / `自动流水线` / `全自动流水线` / `批量开发`
- `自动接单` / `帮我接需求`

### 2. 前置配置

| 配置项 | 说明 | 必须 |
|--------|------|------|
| `templates/products.yaml` | 产品仓库配置表 | 是 |
| TFS PAT Token | 环境变量或 git credentials | 是 |
| git credentials | `~/.git-credentials`，用于 clone/push 免密 | 是 |
| `WECHAT_WEBHOOK_URL` | 企微通知 Webhook，配置在 `~/.bashrc` | 否 |

### 3. TFS 标签体系

工作项必须带 `AI-AUTO-DEV` 标签才会被自动处理，搭配技能标签控制路由：

| 标签 | 含义 | 路由策略 |
|------|------|----------|
| `AI-AUTO-DEV` | 必须有，标记为自动开发需求 | — |
| `AI-BACKEND` | 后端任务 | 只路由到 backend-dev 仓库 |
| `AI-FRONTEND` | 前端任务 | 只路由到 frontend-dev 仓库 |
| `AI-RDF` | RDF 快开任务 | 只路由到 rdf-dev 仓库 |
| `AI-FULLSTACK` | 全栈 | 所有仓库，按各自 skill 路由 |

## 执行流程

```
TFS标签筛选(AI-AUTO-DEV)
  → 需求解析(产品名+技能标签)
    → 匹配 products.yaml
      → 准备开发环境（worktree 或直接创建分支）
        → PM 分析需求(输出开发指令)
          → 技能路由按仓库执行编码
            → git-merge 提交推送
              → TFS PR 创建 + 自动评审
                → 生成处理报告(评论+附件上传)
                  → 企微/终端通知
```

## 目录结构

```
SKILL_DIR/（auto-dev 安装目录）
  ├── SKILL.md                  ← 技能定义入口
  ├── README.md                 ← 本文件
  ├── config.env                ← 环境配置
  ├── prompts/
  │   └── process-demand.md     ← 单需求处理子 agent prompt
  ├── references/
  │   ├── bypass-strategies.md  ← 各技能的 bypass 策略表(唯一来源)
  │   ├── products-config.md    ← products.yaml 配置说明
  │   └── permission-config-guide.md ← 权限配置完整指南
  ├── templates/
  │   ├── products.yaml         ← 产品配置表(实际使用，本地文件不提交)
  │   ├── products-template.yaml← 产品配置模板(新增产品参考)
  │   ├── project-settings.json ← 项目级权限配置模板
  │   └── report-template.md    ← AI 处理报告模板
  └── scripts/
      ├── init-repo.sh          ← 仓库初始化/更新
      ├── setup-worktree.sh     ← worktree 管理
      ├── parse-products.py     ← products.yaml 解析
      ├── add-product.py        ← 新增产品条目
      ├── wechat-notify.sh      ← 企微通知(shell 入口)
      └── wechat-notify.py      ← 企微通知(Python 实现)
```

## 依赖技能

| 技能 | 用途 |
|------|------|
| `pm` | 需求分析，输出开发指令 |
| `backend-dev` | Java Spring Boot 后端开发 |
| `frontend-dev` | Vue 3 前端开发 |
| `rdf-dev` | RDF 快开框架开发 |
| `git-merge` | Git 提交推送与分支合并 |
| `tfs-pr-skill` | TFS PR 创建与代码评审 |

## 注意事项

- **不要触发场景**：`开发需求 1506090`（无"自动"前缀）会路由到单技能（backend-dev 等），不走全链路
- **单仓库失败**不会阻塞其他仓库，失败信息记录到 `summary.md`
- **产品名匹配**基于 TFS 字段 `Winning.Module.name` 与 `products.yaml` 精确匹配
- 详细配置说明见 `references/products-config.md`
