## 前置条件

- 阶段2已完成，`{WORK_DIR}/docs/dev-plan.md` 已存在
- `{LOG_FILE}` 已由阶段1创建，本阶段追加日志

**前置读取**：读取 `{WORK_DIR}/docs/dev-plan.md` 获取开发计划，按计划执行编码。

## 执行流程

### Step 6: 编码

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] 开始编码阶段" >> {LOG_FILE}
```

按 dev-plan.md 逐仓库执行对应 dev 技能（backend-dev / frontend-dev / rdf-dev）。

每个 dev 技能的 bypass 策略详见 `SKILL_DIR/references/bypass-strategies.md` 中对应技能的表格（backend-dev bypass / frontend-dev bypass / rdf-dev bypass）。读取该文件后按 auto-dev 列执行。

执行顺序：先 backend-dev → 再 frontend-dev → 最后 rdf-dev

**立即上传产出文档**（如存在）：
```
mcp__tfs-mcp__tfs_upload_attachment({ id: {DEMAND_ID}, filePath: "{WORK_DIR}/docs/summary.md" })
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] 编码完成，summary.md 已上传" >> {LOG_FILE}
```

### Step 7: 改动量检查

编码完成后，统计改动：
```bash
cd {WORK_DIR}/{仓库名}
git diff --stat
```

从 products.yaml 读取产品的 `change_limits` 配置（未配置则默认 max_files=20, max_insertions=500）。

检查条件（OR 关系，任一超标即跳过）：
- 改动文件数 > max_files
- insertions（新增行数）> max_insertions

超标时：
```
mcp__tfs-mcp__tfs_add_tags({DEMAND_ID}, "AI-SKIPPED")
mcp__tfs-mcp__tfs_add_comment({DEMAND_ID}, "AI自动开发跳过: 改动量超标({N}个文件, {M}行insertions)")
git checkout . && git clean -fd  # 清理改动（包括 untracked 文件）
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] 改动量超标，已跳过: {N}个文件, {M}行insertions" >> {LOG_FILE}
```

返回跳过结果 → 结束。

### Step 7.5: 查询/创建关联任务

**核心规则：代码提交和 PR 必须关联到 Task 类型工作项，严禁直接关联需求。严禁"模拟"Task ID — 必须通过 TFS MCP 真实创建或匹配。**

**7.5a 确认 TFS 集合**（已在 shared-header 中设置，此处仅验证）：

确认集合已设置为 `{TFS_COLLECTION}`（由 shared-header 的 TFS 集合规则在阶段开始时设置）。如果尚未设置（shared-header 中 `{TFS_COLLECTION}` 为空），则从 products.yaml 提取并设置：
```bash
TFS_COLLECTION=$(python SKILL_DIR/scripts/parse-products.py {产品名} product_info | grep 'tfs_project:' | awk '{print $2}' | cut -d'/' -f1)
if [ -n "$TFS_COLLECTION" ]; then
  mcp__tfs-mcp__tfs_set_collection({ collection: "$TFS_COLLECTION" })
fi
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] [Step 7.5a] TFS 集合已设置: $TFS_COLLECTION" >> {LOG_FILE}
```

**7.5b 查询子任务列表**（含重试，最多 3 次）：
```
mcp__tfs-mcp__tfs_get_relations({ id: {DEMAND_ID}, relationType: "children" })
```
如果调用失败，等待 5 秒后重试，最多重试 3 次。每次重试需记录日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] [Step 7.5b 重试] 第 N 次重试查询子任务列表..." >> {LOG_FILE}
```

**7.5c 匹配已有任务**（如果查询到子任务列表非空）：

先获取当前用户标识（与阶段1中确定的产品配置用户一致），然后对每个子任务调用 `mcp__tfs__tfs_get_workitem` 获取详情（包括 `assignedTo` 字段）。

按以下优先级逐个检查子任务：
1. **指派给当前用户的任务**：`assignedTo` 包含当前用户名 → 直接复用该任务 ID（最高优先级，确保 AI 认领自己的任务而非他人的）
2. 标题包含 `AI开发` 或 `AI-AUTO-DEV` → 直接复用该任务 ID
3. 标题与需求标题 `{DEMAND_TITLE}` 高度相似（包含相同核心关键词）→ 复用
4. 无匹配 → 进入 7.5d 创建新任务

**7.5d 创建新任务**（如果无子任务或无匹配项，含重试，最多 3 次）：

读取 dev-plan.md 和 summary.md（如存在）的内容作为任务描述摘要。

**从 tfs_project 提取项目名**（"/" 后的部分）用于创建工作项：
```bash
# tfs_project 格式可能为 "WN_HIS/患者服务平台" 或 "患者服务平台"
# 需要提取最后一部分作为项目名
TFS_PROJECT=$(python SKILL_DIR/scripts/parse-products.py {产品名} product_info | grep 'tfs_project:' | awk '{print $2}')
# 如果包含 "/"，取最后一部分；否则直接使用
PROJECT_NAME=$(echo "$TFS_PROJECT" | awk -F'/' '{print $NF}')
```

**获取指派人和迭代路径**（从需求工作项获取）：
```bash
WORK_ITEM=$(mcp__tfs-mcp__tfs_get_workitem({ id: {DEMAND_ID} }))
# 指派人：优先 devLeader（开发负责人），为空则取 assignedTo（需求指派人）
ASSIGNED_TO=$(echo "$WORK_ITEM" | jq -r '.devLeader // ""')
if [ -z "$ASSIGNED_TO" ]; then
  ASSIGNED_TO=$(echo "$WORK_ITEM" | jq -r '.assignedTo // ""')
fi
# 迭代路径：取需求的迭代
ITERATION_PATH=$(echo "$WORK_ITEM" | jq -r '.iterationPath // ""')
```

```
mcp__tfs-mcp__tfs_create_workitem({
  project: "{PROJECT_NAME}",
  workItemType: "Task",
  title: "AI开发: {DEMAND_TITLE}",
  description: "自动开发任务，关联需求 #{DEMAND_ID}。\n\n## 开发计划摘要\n{从 dev-plan.md 提取前 500 字}",
  parentWorkItemId: {DEMAND_ID},
  assignedTo: "{ASSIGNED_TO}",
  iterationPath: "{ITERATION_PATH}"
})
```

获取创建结果中的任务 ID。
如果调用失败，等待 5 秒后重试，最多重试 3 次。每次重试需记录日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] [Step 7.5d 重试] 第 N 次重试创建子任务..." >> {LOG_FILE}
```

**7.5e 验证 Task 创建结果**（必须执行，不可跳过）：

**验证1 — 确认 Task 存在**：
```
mcp__tfs-mcp__tfs_get_workitem({ id: TASK_ID })
```
如果返回错误（Task 不存在），记录日志并进入降级流程：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] [Step 7.5e] 验证失败: Task #{TASK_ID} 不存在，降级使用需求 ID" >> {LOG_FILE}
```
→ 降级：TASK_ID = DEMAND_ID，TASK_LINK_DEGRADED = true

**验证2 — 确认父子关系**：
```
mcp__tfs-mcp__tfs_get_relations({ id: {DEMAND_ID}, relationType: "children" })
```
检查返回的子项列表中是否包含 TASK_ID。如果不包含，说明父子关系未建立，记录日志并进入降级流程：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] [Step 7.5e] 验证失败: Task #{TASK_ID} 不是需求 #{DEMAND_ID} 的子项，降级使用需求 ID" >> {LOG_FILE}
```
→ 降级：TASK_ID = DEMAND_ID，TASK_LINK_DEGRADED = true

**7.5f 保存 TASK_ID**：

将匹配到或新创建的 Task ID 保存为变量 `TASK_ID`，供后续阶段使用。

```
TASK_ID = {匹配到或创建的任务 ID}
```

**降级策略**：如果经过 3 次重试后查询/创建仍然全部失败，或验证步骤发现 Task 不存在/未关联，**必须降级使用 DEMAND_ID（严禁"模拟"或"自动生成" Task ID）**。降级时**必须**设置降级标志变量：
```
TASK_ID = {DEMAND_ID}
TASK_LINK_DEGRADED = true
DEGRATION_REASON = "{具体的失败原因和最后一次错误信息}"
```

**保存 TASK_ID 到文件，供后续阶段读取**：
```bash
echo "{TASK_ID}" > {WORK_DIR}/docs/.task-id
if [ "{TASK_LINK_DEGRADED}" = "true" ]; then
  echo "true" > {WORK_DIR}/docs/.task-degraded
  echo "{DEGRATION_REASON}" > {WORK_DIR}/docs/.degrade-reason
fi
```

**降级告警**：当 `TASK_LINK_DEGRADED = true` 时，在以下环节必须标注告警：
1. **后续阶段 commit message 末尾追加**：`⚠️ [降级告警] 子任务创建失败，代码直接关联需求 #{DEMAND_ID}。原因：{DEGRATION_REASON}`
2. **最终报告**：在报告顶部添加醒目的降级告警段落
3. **TFS 需求评论**：使用 `mcp__tfs-mcp__tfs_add_comment` 在需求工作项上添加评论：`⚠️ AI自动开发降级告警：子任务创建失败（3 次重试均未成功），代码直接关联需求 #{DEMAND_ID}。原因：{DEGRATION_REASON}。请手动创建子任务并关联代码提交。`

## 阶段完成

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [编码] 阶段完成" >> {LOG_FILE}
```

输出阶段结果，DATA 中必须包含：
```
DATA:
  TASK_ID={TASK_ID}
  TASK_LINK_DEGRADED={true|false}
```

DETAILS 中包含：
- 编码涉及的仓库列表及每个仓库的改动概况
- 改动量检查结果（文件数、insertions）
- TASK_ID 及其来源（匹配/新建/降级）
- 阶段耗时
