## 前置条件

- 阶段4已完成，PR 已创建
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

读取所有前序产出（用于生成报告）：
- `{WORK_DIR}/docs/.analysis-task-id` — AI分析任务ID（阶段2产出，分析内容已在TFS任务中）
- `{WORK_DIR}/docs/dev-plan.md` — 开发计划（阶段2产出）
- `{WORK_DIR}/docs/summary.md` — 编码总结（阶段3产出）
- `{WORK_DIR}/docs/.pr-review.md` — PR评审摘要（阶段4产出，用于报告"评审结果"段）

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [报告] 开始报告阶段" >> {LOG_FILE}
```

## 执行流程

### Step 10: 生成处理报告并兜底上传

**生成完整报告**（保存到 `{WORK_DIR}/docs/ai-report.md`），内容包含：

1. **基本信息**: 需求号、标题、产品、技能标签、处理时间、耗时
2. **PM 分析摘要**: 从 `docs/dev-plan.md` 提取（分析内容已写入TFS AI分析任务）
3. **开发指令摘要**: 从 `docs/dev-plan.md` 提取
4. **代码变更详情**: 从 git diff 收集每个仓库的变动
5. **DDL 变更**（如有）
6. **评审结果**: PR 自动评审摘要
7. **跳过/失败原因**（如有）

如果处于降级模式（TASK_LINK_DEGRADED = true），在报告顶部添加醒目的降级告警段落。

**收集变更数据**（对每个仓库执行）：
```bash
cd {WORK_DIR}/{仓库名}
git diff --stat origin/{base_branch}...HEAD
git log --oneline origin/{base_branch}..HEAD
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [报告] 报告生成完成: ai-report.md" >> {LOG_FILE}
```

**上传 ai-report.md**（必须执行，不可跳过）：仅上传本次新生成的报告文件。`dev-plan.md`、`summary.md` 已在阶段2/3上传，不再重复。

先查询已有附件，确认哪些需要上传：
```
mcp__tfs-mcp__tfs_list_attachments({ id: {DEMAND_ID} })
```

仅上传不在已有附件列表中的文件（文件须存在才能上传）：
```
mcp__tfs-mcp__tfs_upload_attachment({ id: {DEMAND_ID}, filePath: "{WORK_DIR}/docs/ai-report.md" })
```

如果已有附件中缺少 dev-plan.md / summary.md 且对应文件存在，则补传缺失的文件。不要重复上传已存在的附件。

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [报告] 附件上传完成" >> {LOG_FILE}
```

**失败/跳过时也生成报告**，内容包含失败步骤、错误信息、已完成的部分变更、建议人工介入方向。

### Step 11: 完成 — 附件验证 + 写入标记文件 + 通知

**附件验证检查点**（在写标记文件之前必须执行）：调用以下命令确认附件已上传，如果附件数为 0 或过少，立即补传：

```
mcp__tfs-mcp__tfs_list_attachments({ id: {DEMAND_ID} })
```

根据返回的附件列表，**仅补传缺失的文件**。对比已有附件名与以下预期文件列表，只上传不在已有列表中且本地存在的文件：
- ai-report.md
- dev-plan.md
- summary.md

不要重复上传已有附件。

**添加 AI-CODING 标签**（验证后再添加）：

**验证 Task 父子关系**（在给 Task 添加标签前必须执行）：
```
mcp__tfs-mcp__tfs_get_relations({ id: {DEMAND_ID}, relationType: "children" })
```
检查返回的子项列表中是否包含 TASK_ID。根据验证结果决定标签添加范围：

- **验证通过**（TASK_ID 在子项列表中）：
```
mcp__tfs-mcp__tfs_add_tags({DEMAND_ID}, "AI-CODING")
mcp__tfs-mcp__tfs_add_comment({DEMAND_ID}, "AI自动开发完成。详细处理报告及过程文档已作为附件上传")
mcp__tfs-mcp__tfs_add_tags({TASK_ID}, "AI-CODING")
```

- **验证失败**（TASK_ID 不在子项列表中，或处于降级模式 TASK_ID=DEMAND_ID）：
```
mcp__tfs-mcp__tfs_add_tags({DEMAND_ID}, "AI-CODING")
mcp__tfs-mcp__tfs_add_comment({DEMAND_ID}, "AI自动开发完成。详细处理报告及过程文档已作为附件上传")
# 不给 Task 添加标签 — 避免标签关联到无关工作项
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [报告] 标签添加完成: 验证结果={验证通过/验证失败}" >> {LOG_FILE}
```

**写入 result-marker.txt**：

成功时：
```bash
cat > {WORK_DIR}/docs/result-marker.txt << 'RESULT_EOF'
STATUS: success
PR_LIST: {仓库名}#{tfs_pr_id};{仓库名2}#{tfs_pr_id2}
CHANGE_STATS: {仓库名}:{N}files:+{M}ins/-{K}dels;{仓库名2}:...
RESULT_EOF
```

发送成功通知（收集变更数据到 ext JSON）：
```bash
cat > {WORK_DIR}/docs/success-ext.json << 'EOF'
{
  "repo": "{仓库名}",
  "branch": "feature/{DEMAND_ID}",
  "base_branch": "{base_branch}",
  "commit": "{COMMIT_HASH}",
  "pr_id": "{tfs_pr_id}",
  "file_count": "{FILE_COUNT}",
  "insertions": "{INS_LINES}",
  "files": "{CHANGED_FILES}",
  "logics": "{关键逻辑}",
  "ddl": ""
}
EOF

bash SKILL_DIR/scripts/wechat-notify.sh success {产品名} {DEMAND_ID} "{DEMAND_TITLE}" {WORK_DIR}/docs/success-ext.json
```

**如果失败**：
```bash
cat > {WORK_DIR}/docs/result-marker.txt << 'RESULT_EOF'
STATUS: failed
FAIL_STEP: {失败的步骤名}
FAIL_ERROR: {错误信息摘要}
RESULT_EOF
```

发送失败通知：
```bash
cat > {WORK_DIR}/docs/fail-ext.json << 'EOF'
{
  "fail_step": "{失败的步骤名}",
  "fail_reason": "{具体错误信息}"
}
EOF

bash SKILL_DIR/scripts/wechat-notify.sh fail {产品名} {DEMAND_ID} "{DEMAND_TITLE}" {WORK_DIR}/docs/fail-ext.json
```

**如果跳过**：
```bash
cat > {WORK_DIR}/docs/result-marker.txt << 'RESULT_EOF'
STATUS: skipped
SKIP_REASON: {跳过原因}
RESULT_EOF
```

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [报告] 标记文件已写入, result-marker.txt" >> {LOG_FILE}
```

## 阶段完成

追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [报告] 阶段完成" >> {LOG_FILE}
```

输出阶段结果，DATA 中必须包含：
```
DATA:
  PR_LIST={仓库名}#{tfs_pr_id};{仓库名2}#{tfs_pr_id2}
  CHANGE_STATS={仓库名}:{N}files:+{M}ins/-{K}dels;{仓库名2}:...
  RESULT_STATUS=success|failed|skipped
```

DETAILS 中包含：
- 报告生成结果
- 附件上传清单
- result-marker.txt 内容
- 企微通知发送结果
- 阶段耗时
