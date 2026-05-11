## 前置条件

- worktree 已由阶段1创建就绪
- `{WORK_DIR}` 已知（从 shared-header 中获取）
- `{LOG_FILE}` 已由阶段1创建，本阶段追加日志

## 执行流程

### Step 4: PM 分析

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PM分析] 开始PM分析阶段" >> {LOG_FILE}
```

**Step 4.0: 创建AI分析任务（在分析开始前）**

从父工作项获取迭代路径和指派人，创建分析子任务：

```javascript
// 获取父工作项详情（含 iterationPath）
mcp__tfs-mcp__tfs_get_workitem({ id: {DEMAND_ID} })
// 提取 iterationPath 和 assignedTo

// 创建AI分析任务
mcp__tfs-mcp__tfs_create_workitem({
  project: "{PROJECT_NAME}",
  workItemType: "Task",
  title: "AI分析任务:{DEMAND_TITLE}",
  parentWorkItemId: {DEMAND_ID},
  assignedTo: "{父需求的 assignedTo}",
  iterationPath: "{父需求的 iterationPath}",
  fields: {
    "Microsoft.VSTS.Scheduling.OriginalEstimate": 1
  }
})
```

立即将任务状态改为"活动"：
```javascript
mcp__tfs-mcp__tfs_change_state({ id: ANALYSIS_TASK_ID, state: "活动" })
```

保存 `ANALYSIS_TASK_ID` 供 Step 4.3 使用。如果创建失败，记录警告并继续（Step 4.3 将被跳过）。

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PM分析] AI分析任务已创建: #{ANALYSIS_TASK_ID}" >> {LOG_FILE}
```

**Step 4.1: 执行PM分析**

加载 pm 技能执行分析，bypass 策略详见 `SKILL_DIR/references/bypass-strategies.md` 中的「PM 分析 bypass」表格。读取该文件后按 auto-dev 列执行。

**关键产出**：`{WORK_DIR}/docs/dev-plan.md`（仅此一个文件，不再生成 pm-analysis.md）

**Step 4.2: 上传 dev-plan.md 附件**

```
mcp__tfs-mcp__tfs_upload_attachment({ id: {DEMAND_ID}, filePath: "{WORK_DIR}/docs/dev-plan.md" })
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PM分析] 产出文档已上传: dev-plan.md" >> {LOG_FILE}
```

**Step 4.3: 分析内容写入AI分析任务（如任务创建成功）**

如果 Step 4.0 成功创建了 `ANALYSIS_TASK_ID`：

1. 读取分析过程产出的所有文档（评估报告、功能需求、TFS分析）
2. 将内容汇总并转换为 HTML 格式
3. 更新到分析任务的 description 字段：
```javascript
mcp__tfs-mcp__tfs_update_workitem({
  id: ANALYSIS_TASK_ID,
  updates: {
    "System.Description": "<h2>AI需求分析报告</h2>\n{HTML内容}"
  },
  comment: "AI分析完成"
})
```
4. 将任务状态改为"已解决"：
```javascript
mcp__tfs-mcp__tfs_change_state({ id: ANALYSIS_TASK_ID, state: "已解决" })
```

如果 Step 4.0 未创建任务（失败或跳过），跳过此步骤。

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PM分析] AI分析任务已完成: #{ANALYSIS_TASK_ID}" >> {LOG_FILE}
```

**Step 4.4: 设置需求状态为"已分析"**

```
mcp__tfs-mcp__tfs_change_state({ id: {DEMAND_ID}, state: "已分析" })
```

如果状态变更失败，记录警告但继续执行。

### Step 5: 范围检查

检查 dev-plan.md 中涉及的仓库是否都在 products.yaml 配置的 repos 列表内。

如果有仓库不在配置中：
```
mcp__tfs-mcp__tfs_add_tags({DEMAND_ID}, "AI-SKIPPED")
mcp__tfs-mcp__tfs_add_comment({DEMAND_ID}, "AI自动开发跳过: PM分析涉及未配置仓库: {仓库列表}")
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PM分析] 范围检查未通过，涉及未配置仓库: {仓库列表}" >> {LOG_FILE}
```

返回跳过结果 → 结束。

## 阶段完成

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PM分析] 阶段完成" >> {LOG_FILE}
```

输出阶段结果，DATA 中必须包含：
```
DATA:
  DEV_PLAN={WORK_DIR}/docs/dev-plan.md
  ANALYSIS_TASK_ID={ANALYSIS_TASK_ID}
```

DETAILS 中包含：
- PM 分析核心结论（一行摘要）
- dev-plan.md 涉及的仓库和技能
- ANALYSIS_TASK_ID（如创建成功）
- 范围检查结果
- 阶段耗时
