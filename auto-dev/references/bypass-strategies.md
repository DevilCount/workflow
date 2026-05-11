# Auto-Dev Bypass 策略表

auto-dev 全自动执行时，需要跳过各技能中的用户交互点。以下列出每个技能的 bypass 策略。

## PM 分析 bypass

| PM阶段 | 正常交互 | auto-dev策略 |
|--------|----------|-------------|
| 阶段0 获取需求 | AskUserQuestion确认需求内容 | **跳过**，直接用TFS工作项内容 |
| 阶段0.5 Wiki获取 | 无交互 | 正常执行 |
| 阶段0.6 创建AI分析任务 | 无交互 | 正常执行 |
| 阶段1 需求评估 | 无交互（内部评分） | 正常执行 |
| 阶段2 需求补充 | AskUserQuestion提问(最多10个) | **跳过**，不补充提问 |
| 阶段3 PRD设计 | 生成PRD后要求用户审阅 | **跳过审阅**，直接采纳 |
| 阶段4 原型设计 | AskUserQuestion选原型工具 | **跳过整个阶段** |
| 阶段5 TFS分析 | 无交互 | 正常执行 |
| 阶段6 上传TFS | AskUserQuestion确认 | **正常执行：字段+标签+附件全部执行** |
| 阶段6.5 完成AI分析任务 | 无交互 | 正常执行 |
| 清理阶段 | AskUserQuestion删除/保留过程文件 | **跳过**，auto-dev统一管理docs目录 |

## backend-dev bypass

| 步骤 | 正常交互 | auto-dev策略 |
|------|----------|-------------|
| Step 0 需求获取 | 获取TFS工作项 | **跳过**，从 dev-plan.md 读取 |
| Step 1 需求分析 | 读取CLAUDE.md | 正常执行 |
| Step 2 生成计划 | superpowers:writing-plans | 正常执行，保存到 docs/plans/ |
| Step 3 用户确认 | AskUserQuestion | **跳过**，自动确认 |
| Step 4 创建分支 | AskUserQuestion选分支名 | **跳过**，Stage 1 已创建 feature 分支（worktree 或 inline 模式） |
| Step 5 编码实现 | 无交互 | 正常执行 |
| Step 6 测试验证 | 无交互 | 正常执行 |
| Step 7 保存记录 | 无交互 | 正常执行 |
| Step 8 上传TFS | AskUserQuestion确认导出 | **跳过**，auto-dev统一处理 |

## frontend-dev bypass

| 步骤 | 正常交互 | auto-dev策略 |
|------|----------|-------------|
| Step 0 需求获取 | 获取TFS工作项 | **跳过**，从 dev-plan.md 读取 |
| Step 1 分析+读取上下文 | 读取CLAUDE.md | 正常执行 |
| Step 2 权限约束检查 | 无交互 | 正常执行 |
| Step 3 生成计划 | superpowers:writing-plans | 正常执行 |
| Step 4 用户确认 | AskUserQuestion | **跳过**，自动确认 |
| Step 5 创建分支 | AskUserQuestion选子模块+分支名 | **跳过**，Stage 1 已创建 feature 分支（worktree 或 inline 模式） |
| Step 6 编码实现 | 无交互 | 正常执行 |
| Step 7 验证 | 无交互 | 正常执行 |
| Step 8 保存记录 | 无交互 | 正常执行 |
| Step 9 上传TFS | AskUserQuestion确认导出 | **跳过**，auto-dev统一处理 |

## rdf-dev bypass

| 步骤 | 正常交互 | auto-dev策略 |
|------|----------|-------------|
| Step 0 需求获取 | 获取TFS工作项 | **跳过**，从 dev-plan.md 读取 |
| Step 1 分析+确认项目 | AskUserQuestion确认目标项目 | **跳过**，从products.yaml读取 |
| Step 2 生成计划 | superpowers:writing-plans | 正常执行 |
| Step 3 用户确认 | AskUserQuestion | **跳过**，自动确认 |
| Step 4 创建分支 | AskUserQuestion选分支名 | **跳过**，Stage 1 已创建 feature 分支（worktree 或 inline 模式） |
| Step 5 编码实现 | 无交互 | 正常执行 |
| Step 6 验证 | 无交互 | 正常执行 |
| Step 7 保存记录 | 无交互 | 正常执行 |
| Step 8 上传TFS | AskUserQuestion确认导出 | **跳过**，auto-dev统一处理 |

## git-merge bypass

| git-merge步骤 | 正常交互 | auto-dev策略 |
|---------------|----------|-------------|
| Step 0 检测项目结构 | AskUserQuestion选择操作仓库 | **自动选择**，对products.yaml中涉及仓库逐一执行 |
| Step 1 检查工作区 | AskUserQuestion(提交/暂存/取消) | **自动提交**，不提供暂存/取消选项 |
| Step 2 关联TFS任务 | AskUserQuestion选任务号 | **自动用 TASK_ID**（Step 7.5 产出，格式：`#{TASK_ID} 提交说明`） |
| Step 2.3 确认commit message | AskUserQuestion | **自动确认**，格式固定为 `#{TASK_ID} {DEMAND_TITLE}` |
| Step 3 选择主分支 | AskUserQuestion | **从products.yaml读取** |
| Step 7 冲突处理 | AskUserQuestion选策略 | **保留本地版本(-X ours)** |
| Step 8 验证失败 | AskUserQuestion是否继续 | **自动继续，但在 result-marker.txt 中记录警告** |
| **Step 10 前分支保护检查** | **脚本自动检查** | **强制执行，不可 bypass**。检查当前分支是否为保护分支（products.yaml 中的 default_branch / repos[].branch），是则拒绝推送并报错退出 |
| Step 10 推送 | AskUserQuestion确认 | **自动推送**（仅当分支保护检查通过后） |

## tfs-pr-skill bypass

| tfs-pr-skill步骤 | 正常交互 | auto-dev策略 |
|------------------|----------|-------------|
| 步骤3c 选择任务号 | AskUserQuestion | **自动用 TASK_ID**（Step 7.5 产出，关联 Task 而非需求） |
| 步骤4 确认PR信息 | AskUserQuestion | **自动确认** |
| 步骤6后 发布评审 | AskUserQuestion选操作 | **自动发布到PR评论** |
| 大PR(>20文件) | AskUserQuestion全量/核心评审 | **自动全量评审**，不跳过任何文件 |
