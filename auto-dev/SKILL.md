---
name: auto-dev
description: |
  全自动开发流水线 - 从需求分析到代码提交一站式完成。
  输入 TFS 工作项 ID，自动调度 pm→dev→git-merge→tfs-pr。
  支持单工作项和批量处理。

  **必须触发**（包含以下任一即触发）：
  - "自动开发" + 数字：如"自动开发 1506090"、"全自动开发需求 1506090"
  - "auto-dev"、"自动流水线"、"全自动流水线"、"批量开发"
  - "接需求" + 自动/全自动：如"帮我接需求"、"自动接单"
  - 用户明确要求全链路处理（PM分析+编码+提交+PR 一站式完成）

  **不要触发**（由 backend-dev/frontend-dev/rdf-dev 单技能处理）：
  - "开发需求 1506090"、"帮我开发 1506090"（无"自动"前缀 → 走单技能）
  - "实现接口"、"写个页面"等单一开发任务

  **依赖技能**：pm, backend-dev, frontend-dev, rdf-dev, git-merge, tfs-pr-skill
tags: [研发, DevOps, 工具]
keywords: 自动开发 全自动开发 自动流水线 全自动流水线 批量开发 auto-dev 全链路 需求开发 自动接单 TFS工作项 一站式开发 PM分析 自动评审 worktree
metadata:
  author: 晁兴鹏
  version: 1.0.0
---

# Auto-Dev 全链路自动化开发

## 概述

从TFS标签筛选需求开始，到代码提交PR完成，全程自动化。

```
TFS标签筛选(AI-AUTO-DEV)
  → 需求解析(产品名+技能标签)
    → 匹配products.yaml
      → git worktree隔离
        → PM分析需求(输出开发指令)
          → 技能路由(dev)按仓库执行
            → 查询/创建Task子任务
              → git-merge提交(#TaskID)
                → TFS PR创建+自动评审
                → 生成处理报告(评论+附件上传TFS)
                  → 企微/终端通知
```

## 目录结构

```
# 新模式（base_path 配置时，推荐）：
{base_path}/auto-dev-{需求号}/  ← worktree工作目录
# 例如 base_path=D:/代码/自助机(HSS)/01 自助机系统/V6.0, 需求号=1931988
# → D:/代码/自助机(HSS)/01 自助机系统/V6.0/auto-dev-1931988/
  ├── winning-xxx/           ← feature/{需求号} 分支
  ├── winning-yyy/
  └── docs/                  ← 工作文档
      ├── .analysis-task-id  ← AI分析任务ID
      ├── dev-plan.md        ← 开发计划(PM产出→dev消费)
      ├── summary.md         ← 执行结果总结
      └── ai-report.md       ← AI处理报告(上传到TFS)

# 兼容模式（source_path 配置时，旧逻辑）：
{source_path父目录}_{需求号}/  ← worktree工作目录
# 例如 source_path=/f/.../mdm-group/winning-group-mdm, 需求号=1506090
# → /f/.../mdm-group_1506090/

# 标准模式（无 base_path/source_path 时）：
~/auto/{产品名}/{需求号}/     ← worktree工作目录
~/tfs/{产品名}/              ← 仓库主目录(git clone，标准模式)
  ├── winning-xxx/
  └── winning-yyy/

SKILL_DIR/
  ├── SKILL.md                  ← 本文件
  ├── config.env                ← 环境配置(企微Webhook URL + TFS查询URL)
  ├── prompts/
  │   ├── shared-header.md        ← 公共约束头（各阶段共享）
  │   ├── stage-1-prepare.md      ← 阶段1: 准备(Steps 0-3)
  │   ├── stage-2-pm.md           ← 阶段2: PM分析(Steps 4-5)
  │   ├── stage-3-code.md         ← 阶段3: 编码(Steps 6-7.5)
  │   ├── stage-4-submit.md       ← 阶段4: 提交+PR(Steps 8-9)
  │   ├── stage-5-report.md       ← 阶段5: 报告(Steps 10-11)
  │   └── process-demand.md       ← [已废弃] 原单Agent prompt，仅供参考
  ├── references/
  │   ├── bypass-strategies.md  ← 各技能的bypass策略表(唯一来源)
  │   ├── products-config.md    ← products.yaml配置说明+FAQ
  │   └── permission-config-guide.md ← 权限配置完整指南
  ├── templates/
  │   ├── products.yaml         ← 产品配置表(实际使用，本地文件不提交)
  │   ├── products-template.yaml← 产品配置模板(新增产品参考)
  │   ├── project-settings.json ← 项目级权限配置模板
  │   └── report-template.md    ← AI处理报告模板
  └── scripts/
      ├── init-repo.sh          ← 仓库初始化/更新
      ├── setup-worktree.sh     ← worktree管理
      ├── parse-products.py     ← products.yaml解析
      ├── add-product.py        ← 新增产品配置
      ├── detect-local-repos.sh ← 本地仓库扫描（新增）
      ├── register-product.py   ← 本地产品注册（新增）
      ├── wechat-notify.sh      ← 企微通知(shell入口)
      └── wechat-notify.py      ← 企微通知(Python实现)
```

## 标签体系

TFS工作项必须带以下标签才会被自动处理：

| 标签 | 含义 | 路由策略 |
|------|------|----------|
| `AI-AUTO-DEV` | 必须有，表示该需求参与自动开发 | - |
| `AI-BACKEND` | 后端任务 | 只处理 skill=backend-dev 的仓库 |
| `AI-FRONTEND` | 前端任务 | 只处理 skill=frontend-dev 的仓库 |
| `AI-RDF` | RDF快开任务 | 只处理 skill=rdf-dev 的仓库 |
| `AI-FULLSTACK` | 全栈 | 所有仓库都处理，按各自 skill 分别路由 |

---

## 执行流程

**Step 0-11 全自动，无需用户确认。**

根据输入判断模式：
- **单个需求号**（如 "自动开发 1506090"）→ 单需求模式
- **多个需求号**（如 "自动开发 1506090 1506091 1506092"）→ 批量模式

---

### Step 0: 接收需求 + 用户确认

**输入**: TFS 工作项 ID（用户给出）

**1. 获取工作项详情**：
```
mcp__tfs-mcp__tfs_get_workitem({ id: 需求号 })
```

**2. 检查标签**：
- 必须包含 `AI-AUTO-DEV`，没有则警告但继续
- 提取技能标签：AI-BACKEND / AI-FRONTEND / AI-RDF / AI-FULLSTACK

**3. 下载附件**：
```
mcp__tfs-mcp__tfs_download_attachments({ id: 需求号, targetDir: "{WORK_DIR}/docs/" })
```

**4. 识别产品名称**：

读取工作项字段 `Winning.Module.name`，trim 前后空格，与 products.yaml 中的产品名称进行**精确匹配**（严格字符串相等）。

- **匹配成功** → 自动确认产品名，进入步骤 4.5（场景 A：检查 source_path、本地模式）
- **匹配失败** → 按以下优先级处理：
  1. products.yaml **有产品配置** → 列出所有产品名让用户选，选定后进入步骤 4.5（场景 A）
  2. products.yaml **无产品配置** → 进入步骤 4.5（场景 B：自动发现并注册产品）
  3. 以上均无法确定产品 → 提示用户先配置 products.yaml，终止流程

**4.5 本地目录检测**（以下两种场景触发）：
- 场景 A：产品匹配成功或用户选择产品后（检查 source_path、本地模式）
- 场景 B：products.yaml 为空，尝试从当前目录自动发现并注册产品

检测流程：

1. 调用检测脚本：
   ```bash
   bash SKILL_DIR/scripts/detect-local-repos.sh
   ```
2. 如果输出非空 JSON 数组（发现本地 TFS 仓库）：
   - 检查这些仓库是否已在 products.yaml 中有 `source_path` 配置
   - 如果已有 → 标记为"本地模式"，后续跳过 init-repo
   - 如果没有 → 进入注册流程：
     a. 展示扫描到的仓库列表
     b. 用户输入产品名称（用于 products.yaml 的 key）
     c. 调用注册脚本：
        ```bash
        # 将扫描结果保存到临时文件
        bash SKILL_DIR/scripts/detect-local-repos.sh > /tmp/local-repos.json
        python SKILL_DIR/scripts/register-product.py --name "{用户输入的产品名}" --repos-file /tmp/local-repos.json
        ```
     d. 用注册后的产品名继续后续流程
3. 如果输出空数组：
   - 场景 A（有产品配置）→ 走原有 init-repo 流程
   - 场景 B（无产品配置）→ 提示用户先配置 products.yaml 或在产品仓库目录下运行，终止流程

**5. 确定仓库列表和技能路由**：
- 根据标签筛选仓库：AI-BACKEND → 只 skill=backend-dev 的仓库
- 无技能标签 → 使用产品 default_skill 对应的仓库
- AI-FULLSTACK → 所有仓库，按各自 skill 路由

**6. 输出确认信息**（仅展示，自动继续）：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 需求接单确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
需求号: 1506090
标题: XXXXX
产品: {产品名}
标签: AI-BACKEND

涉及仓库:
  [后端] repo-backend (develop → feature/1506090)
  [后端] repo-service (develop → feature/1506090)

技能路由: backend-dev × 2个仓库
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
自动继续执行 Step 1...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### Step 1-5: 分阶段委托子 Agent

**关键：Step 1-11 拆分为 5 个阶段，每个阶段由独立的前台子 Agent 执行，完成即显示摘要。**

#### 阶段编排流程

主 agent 完成 Step 0（需求确认）后，**必须**按顺序调用 5 个前台 Agent：

**阶段 1: 准备（Steps 0-3）**
```
1. 读取 SKILL_DIR/prompts/shared-header.md 和 SKILL_DIR/prompts/stage-1-prepare.md
2. 替换占位符：
   - {DEMAND_ID}, {DEMAND_TITLE}, {DEMAND_TAGS}, {产品名} → 实际值
   - {TFS_COLLECTION} → 从 products.yaml 的 tfs_project 提取集合名（"/" 前的部分，如 "WN_TECH"），需确保子 Agent 在正确集合中操作
   - {WORK_DIR} → 已计算的工作目录
   - {LOG_FILE} → 留空（阶段1 Step 0 前置步骤会创建并赋值，shared-header 中的引用会在实际使用时被 shell 变量覆盖）
   - {STAGE_NAME} → 准备, {STAGE_NUM} → 1
3. 将 shared-header.md 内容 + stage-1-prepare.md 内容拼接为 prompt
4. 调用 Agent({ description: "准备阶段 需求 {需求号}", prompt: 拼接后的prompt })
5. 解析返回的 STAGE_RESULT
6. 显示阶段摘要
```

**阶段 2-5: 后续阶段**
```
同上，但：
- 读取对应的 stage-N-xxx.md
- {LOG_FILE} 替换为阶段1返回的 DATA.LOG_FILE 值
- 前一阶段 STATUS=failed → 不调用后续阶段，执行善后处理（见下方）
- 前一阶段 STATUS=skipped → 不调用后续阶段，执行善后处理（见下方）
```

#### 中间阶段失败/跳过的善后处理

当**任意阶段**（1-4）返回 failed 或 skipped 时，后续阶段不再调用，**主 agent 必须执行以下善后操作**：

**1. 写入 result-marker.txt**
```bash
mkdir -p {WORK_DIR}/docs
cat > {WORK_DIR}/docs/result-marker.txt << EOF
STATUS: {STAGE_RESULT中的STATUS}
FAIL_STEP: {FAIL_STEP，如有}
FAIL_ERROR: {FAIL_ERROR，如有}
SKIP_REASON: {SKIP_REASON，如有}
EOF
```

**2. 发送企微通知**（根据 STATUS 二选一）：

STATUS=failed 时：
```bash
cat > {WORK_DIR}/docs/fail-ext.json << EOF
{"fail_step": "{FAIL_STEP}", "fail_reason": "{FAIL_ERROR}"}
EOF
bash SKILL_DIR/scripts/wechat-notify.sh fail {产品名} {DEMAND_ID} "{DEMAND_TITLE}" {WORK_DIR}/docs/fail-ext.json
```

STATUS=skipped 时：
```bash
cat > {WORK_DIR}/docs/skip-ext.json << EOF
{"skip_reason": "{SKIP_REASON}"}
EOF
bash SKILL_DIR/scripts/wechat-notify.sh fail {产品名} {DEMAND_ID} "{DEMAND_TITLE}" {WORK_DIR}/docs/skip-ext.json
```

**3. 显示最终摘要**（按下方"最终汇总"格式输出，标注失败/跳过）

注：worktree 保留不清理，供人工介入排查。TFS 标签（AI-SKIPPED）和评论已由各阶段内部处理。

#### prompt 构造方法

每个阶段的 prompt 由两部分拼接：

1. **公共头**：读取 `SKILL_DIR/prompts/shared-header.md`，替换占位符
   - `{STAGE_NAME}` → 阶段名（准备/PM分析/编码/提交+PR/报告）
   - `{STAGE_NUM}` → 1/2/3/4/5
   - `{DEMAND_ID}`, `{DEMAND_TITLE}`, `{DEMAND_TAGS}`, `{产品名}`, `{WORK_DIR}` → 实际值
   - `{LOG_FILE}` → 日志文件路径（阶段1返回后从 DATA 中获取）
2. **阶段内容**：读取 `SKILL_DIR/prompts/stage-N-xxx.md`，替换同样的占位符

最终 prompt = 公共头（替换后） + 阶段内容（替换后）

#### 阶段摘要显示格式

每个阶段完成后，解析返回的 STAGE_RESULT，按以下格式显示：

```
━━━ [N/5] {阶段名} ✅ ━━━
  {DETAILS 中的每行内容，缩进2空格}
```

失败时：
```
━━━ [N/5] {阶段名} ❌ ━━━
  失败步骤: {FAIL_STEP}
  错误: {FAIL_ERROR}
  ⚠️ 后续阶段已跳过
```

跳过时：
```
━━━ [N/5] {阶段名} ⏭️ ━━━
  跳过原因: {SKIP_REASON}
```

#### 阶段间数据传递

上下文通过磁盘文件传递（子 Agent 读取/写入）：

| 文件 | 写入阶段 | 读取阶段 | 内容 |
|------|---------|---------|------|
| `{WORK_DIR}/docs/auto-dev-*.log` | 阶段1创建，各阶段追加 | 所有阶段 | 操作日志 |
| `{WORK_DIR}/docs/.analysis-task-id` | 阶段2 | 阶段5 | AI分析任务ID（分析内容写入TFS任务） |
| `{WORK_DIR}/docs/dev-plan.md` | 阶段2 | 阶段3/5 | 开发计划 |
| `{WORK_DIR}/docs/summary.md` | 阶段3 | 阶段5 | 编码总结 |
| `{WORK_DIR}/docs/.task-id` | 阶段3 | 阶段4/5 | Task ID |
| `{WORK_DIR}/docs/.task-degraded` | 阶段3（降级时） | 阶段4/5 | 降级标志 |
| `{WORK_DIR}/docs/.degrade-reason` | 阶段3（降级时） | 阶段4/5 | 降级原因 |
| `{WORK_DIR}/docs/.pr-review.md` | 阶段4 | 阶段5 | PR评审摘要 |
| `{WORK_DIR}/docs/result-marker.txt` | 阶段5 / 主agent(善后) | 主agent | 最终结果 |
| `{WORK_DIR}/docs/ai-report.md` | 阶段5 | 主agent | 完整报告 |

#### 最终汇总

全部 5 个阶段完成后，主 agent 输出最终汇总（格式与现有一致）：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 自动开发完成 / ❌ 自动开发失败
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
需求号: {需求号}
标题: {需求标题}
产品: {产品名}

仓库变更:
  {仓库名} ({skill}): {N} files (+{M} -{K})

PR列表:
  - {仓库名}: PR #{tfs_pr_id}

评审结果: {评审摘要}

日志: {LOG_FILE}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> 各字段数据来源：
> - PR列表: 阶段5返回的 DATA.PR_LIST
> - 仓库变更统计: 阶段5返回的 DATA.CHANGE_STATS
> - 评审结果: 阶段5返回的 DETAILS 中提取（来自 .pr-review.md）
> - 日志: 阶段1返回的 DATA.LOG_FILE
> 各技能的 bypass 策略表见 `references/bypass-strategies.md`

---

### 批量模式

用户一次给出多个需求号时（如 "自动开发 1506090 1506091 1506092"），进入批量模式。

**批量执行流程**：

1. **发送启动通知**（列出所有待处理需求）：
   ```bash
   # 生成 demand_list JSON
   python3 -c "
   import json, sys
   items = [{'task_id': tid, 'title': '', 'product': ''} for tid in sys.argv[1:]]
   json.dump({'demand_list': items}, open('/tmp/auto-dev-start.json','w'), ensure_ascii=False, indent=2)
   " {需求号1} {需求号2} ...
   bash SKILL_DIR/scripts/wechat-notify.sh start auto-dev batch "批量启动" /tmp/auto-dev-start.json
   ```

2. **逐个处理**：对每个需求号，执行 Step 0 确认 → 5阶段串行调用 → 每阶段显示摘要 → 记录结果。
   - 前一个完成后再处理下一个（串行），避免资源争抢
   - 某个需求失败不影响后续需求

3. **汇总结果**：全部完成后输出汇总表并发送汇总通知。
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   📊 批量处理汇总
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ✅ 1506090: XXX接口开发 → PR #1234
   ❌ 1506091: YYY页面开发 → Step6-编码: 编译失败
   ⏭️ 1506092: ZZZ优化 → 改动量超标
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   成功: 1 | 失败: 1 | 跳过: 1
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

4. **发送汇总通知**：
   ```bash
   # 生成 summary JSON（包含 success_list / failed_list / skipped_list）
   bash SKILL_DIR/scripts/wechat-notify.sh summary auto-dev summary "每日报告" /tmp/auto-dev-summary.json
   ```

---

## 产品名匹配规则

通过 TFS 工作项字段 `Winning.Module.name` 匹配产品：

1. 读取字段值，trim 前后空格
2. 与 products.yaml 中的产品名称进行**精确字符串匹配**（严格相等）
3. 字段为空或匹配失败 → 列出所有已配置产品让用户选择

---

## 仓库筛选规则

根据标签决定处理哪些仓库：

```
标签 AI-BACKEND  → repos 中 skill=backend-dev 的仓库
标签 AI-FRONTEND → repos 中 skill=frontend-dev 的仓库
标签 AI-RDF      → repos 中 skill=rdf-dev 的仓库
标签 AI-FULLSTACK → repos 中所有仓库，按各自的 skill 分别路由
无技能标签       → 使用 default_skill，筛选 skill=default_skill 的仓库
```

---

## FULLSTACK 执行策略

AI-FULLSTACK 标签触发多技能编排，串行执行：
1. 所有 backend-dev 仓库（后端先完成）
2. 所有 frontend-dev 仓库（依赖后端接口）
3. 所有 rdf-dev 仓库（依赖前端框架）

每个仓库独立执行 dev 技能，互不影响。

---

## 错误处理

### 单仓库失败
- 标记该仓库为失败，继续处理其他仓库
- 失败信息记录到 docs/summary.md，最终报告标注失败仓库，企微通知失败原因

### 全部失败
- 停止后续步骤（不创建PR），保留 worktree 供人工介入，企微通知失败

### worktree 冲突
- 自动尝试 `git merge -X ours` 解决
- 无法自动解决 → 标记失败，通知用户

---

## 前置配置清单

### 必须配置

| 配置项 | 位置 | 说明 |
|--------|------|------|
| products.yaml | templates/products.yaml | 产品仓库配置 |
| TFS PAT Token | 环境变量或 git credentials | TFS API + git 访问 |
| git credentials | ~/.git-credentials | git clone/push 免密 |
| 权限配置 | ~/.claude/settings.json 或 ~/tfs/{产品名}/.claude/settings.json | 子 agent 执行权限 |

### 权限配置

**推荐：项目级权限**（更安全）

```bash
# 创建产品目录的权限配置
mkdir -p ~/tfs/{产品名}/.claude
cp SKILL_DIR/templates/project-settings.json ~/tfs/{产品名}/.claude/settings.json
```

**或：全局权限**

在 `~/.claude/settings.json` 中添加 `permissions.allow`，详见 `references/permission-config-guide.md`

### 可选配置

| 配置项 | 位置 | 说明 |
|--------|------|------|
| WECHAT_WEBHOOK_URL | 环境变量 | 企微通知 Webhook URL |
| 仓库已 clone | ~/tfs/{产品名}/ | 未clone则自动执行 init-repo.sh |
| 本地产品已 clone | 任意路径 | 本地仓库有 .git 即可，首次运行自动注册 |

### 企微 Webhook 配置

```bash
echo 'export WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR-KEY"' >> ~/.bashrc
source ~/.bashrc
bash SKILL_DIR/scripts/wechat-notify.sh start {产品名} test
```

> products.yaml 的详细配置说明和新增产品模板见 `references/products-config.md`
