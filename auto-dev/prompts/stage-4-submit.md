## 前置条件

- 阶段3已完成，TASK_ID 已写入 `{WORK_DIR}/docs/.task-id`
- `{LOG_FILE}` 已由阶段1创建，本阶段追加日志

**前置读取**：
```bash
# 读取前序阶段数据
TASK_ID=$(cat {WORK_DIR}/docs/.task-id)
if [ -f "{WORK_DIR}/docs/.task-degraded" ]; then
  TASK_LINK_DEGRADED=$(cat {WORK_DIR}/docs/.task-degraded)
  DEGRATION_REASON=$(cat {WORK_DIR}/docs/.degrade-reason)
fi
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [提交+PR] 开始提交+PR阶段, TASK_ID={TASK_ID}" >> {LOG_FILE}
```

## 执行流程

### Step 8: Git 提交推送

**分支保护预检（每个仓库推送前必须执行）**：
```bash
cd {WORK_DIR}/{仓库名}
CURRENT_BRANCH=$(git branch --show-current)
# 当前分支必须以 feature/ 开头且包含 DEMAND_ID
[[ "$CURRENT_BRANCH" == "feature/${DEMAND_ID}"* ]] || { echo "BLOCKED: 当前分支 '$CURRENT_BRANCH' 不符合 feature/{DEMAND_ID}* 格式，禁止推送"; exit 1; }
# 当前分支不能是 products.yaml 中配置的保护分支
REPO_BRANCHES=$(python SKILL_DIR/scripts/parse-products.py {产品名} name,branch | cut -d'|' -f2)
DEFAULT_BRANCH=$(python SKILL_DIR/scripts/parse-products.py {产品名} product_info | grep 'default_branch:' | awk '{print $2}')
echo -e "${REPO_BRANCHES}\n${DEFAULT_BRANCH}" | sort -u | grep -v '^$' | grep -qxF "$CURRENT_BRANCH" && { echo "BLOCKED: 当前分支 '$CURRENT_BRANCH' 是保护分支，禁止推送"; exit 1; }
```

如果预检失败：**立即中止该仓库的推送**，追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [提交+PR] 分支保护检查失败: {错误信息}" >> {LOG_FILE}
```
返回失败结果（FAIL_STEP: Step 8 分支保护检查）。**严禁绕过此检查。**

通过预检后，加载 git-merge 技能，bypass 所有交互点：
- 自动提交
- commit message 格式：
  - 正常模式：`#{TASK_ID} {DEMAND_TITLE}`
  - 降级模式（TASK_LINK_DEGRADED=true）：`#{DEMAND_ID} {DEMAND_TITLE}`（末尾追加降级告警：`⚠️ [降级告警] 子任务创建失败，代码直接关联需求 #{DEMAND_ID}。原因：{DEGRATION_REASON}`）
- 自动关联任务号（TASK_ID，非需求号）
- 自动推送

对每个仓库都要执行 git-merge 流程。

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [提交+PR] 仓库 {仓库名} 提交推送完成" >> {LOG_FILE}
```

**提交完成后，将任务状态设为"活动"**：
```
mcp__tfs-mcp__tfs_change_state({ id: TASK_ID, state: "活动" })
```

如果状态变更失败，记录警告但继续执行。如果处于降级模式（TASK_LINK_DEGRADED = true），跳过此步骤。

### Step 9: 创建 TFS PR

对每个仓库创建 PR，使用 products.yaml 中的配置：

**获取仓库信息**：
```bash
REPO_NAME="{仓库名}"
TFS_PROJECT=$(python SKILL_DIR/scripts/parse-products.py {产品名} name,tfs_project | grep {REPO_NAME} | cut -d'|' -f2)
BASE_BRANCH=$(python SKILL_DIR/scripts/parse-products.py {产品名} name,branch | grep {REPO_NAME} | cut -d'|' -f2)
PROJECT_NAME=$(echo "$TFS_PROJECT" | awk -F'/' '{print $NF}')
# 获取仓库远程 URL（winning-pr 需要 repo_url 参数）
cd {WORK_DIR}/{REPO_NAME}
REPO_URL=$(git remote get-url origin)
```

**创建 PR**（使用 winning-pr MCP 工具）：
```
mcp__winning-pr__create_pr({
  repo_url: "{REPO_URL}",
  source_branch: "feature/{DEMAND_ID}",
  target_branch: "{BASE_BRANCH}"
})
```

对每个仓库创建 PR。**创建完成后，记录每个仓库的 `tfs_pr_id`**（从返回结果中获取）。

**评审 bypass**：跳过自动代码评审和评论发布，直接写入占位文件：
```bash
echo "PR评审已跳过（bypass模式）" > {WORK_DIR}/docs/.pr-review.md
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [提交+PR] 仓库 {仓库名} PR创建完成: #{tfs_pr_id}" >> {LOG_FILE}
```

### Step 9.5: 条件化清理

根据产品的 worktree 配置决定清理行为：
```bash
WORKTREE_MODE=$(python SKILL_DIR/scripts/parse-products.py {产品名} product_info | grep 'worktree:' | awk '{print $2}')
```

- **worktree: true**：记录 worktree 位置（不自动清理，保留供人工检查）
- **worktree: false**：保留 feature 分支，不做任何清理。用户可继续在 feature/{DEMAND_ID} 分支上调试。

## 阶段完成

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [提交+PR] 阶段完成" >> {LOG_FILE}
```

输出阶段结果，DATA 中必须包含：
```
DATA:
  TASK_ID={TASK_ID}
  PR_LIST={仓库名}#{tfs_pr_id};{仓库名2}#{tfs_pr_id2}
  CHANGE_STATS={仓库名}:{N}files:+{M}ins/-{K}dels;{仓库名2}:...
```

DETAILS 中包含：
- 每个仓库的提交信息（commit hash、message）
- 每个仓库的 PR 信息（ID、URL）
- 改动统计（文件数、增删行数）
- 分支保护检查结果
- 阶段耗时
