# AI Auto-Dev 处理报告 - 需求 {DEMAND_ID}

> 生成时间: {TIMESTAMP}

## 基本信息

| 字段 | 值 |
|------|-----|
| 需求号 | {DEMAND_ID} |
| 标题 | {DEMAND_TITLE} |
| 产品 | {PRODUCT_NAME} |
| 技能标签 | {SKILL_TAG} |
| 处理时间 | {START_TIME} ~ {END_TIME} |
| 处理耗时 | 约 {DURATION_MINUTES} 分钟 |

## PM 分析摘要

### 需求理解
{从 dev-plan.md 中提取：核心需求描述、业务背景}

### 技术方案选型
{从 dev-plan.md 中提取：选定的技术方案及理由}

### 功能拆解
{从 dev-plan.md 中提取：功能拆解列表}

## 开发指令摘要

{从 dev-plan.md 中提取：每个仓库的任务分配}

## 代码变更详情

### 仓库: {REPO_NAME} ({SKILL})

- 分支: `feature/{DEMAND_ID}` → `{BASE_BRANCH}`
- Commit: `{COMMIT_HASH}` {COMMIT_MESSAGE}
- PR: #{tfs_pr_id}
- 变动统计: {FILE_COUNT} files (+{INSERTIONS} -{DELETIONS})

**修改文件列表**:

| 文件 | 改动说明 |
|------|----------|
| {FILE_PATH_1} | {CHANGE_DESC_1} |
| {FILE_PATH_2} | {CHANGE_DESC_2} |

**关键逻辑变更**:

- ✅ {LOGIC_1: 新增XXX接口/方法/配置}
- ✅ {LOGIC_2: 修改YYY业务规则}
- ✅ {LOGIC_3: ...}

### 仓库: {REPO_NAME_2} ({SKILL_2})

{同上格式}

## DDL 变更

{如有数据库变更，列出详情}

| 操作 | 表名 | 说明 |
|------|------|------|
| 新增表 | {TABLE_NAME} | {FIELD_LIST} |
| 修改字段 | {TABLE_FIELD} | {CHANGE_DESC} |
| 新增索引 | {INDEX_NAME} | on {TABLE_NAME}({FIELD}) |

{无DDL变更则写: "本次变更无DDL，无需额外数据库操作"}

## 评审结果

{每个PR的自动评审摘要}

| PR | 评审状态 | 发现问题 |
|----|----------|----------|
| {REPO_NAME} #{PR_ID} | {REVIEW_STATUS} | {ISSUES_OR_NONE} |

## 跳过/失败原因

{仅在跳过或失败时填写}

- 失败步骤: {FAIL_STEP}
- 错误信息: {FAIL_ERROR}
- 已完成部分: {COMPLETED_PARTS}
- 建议: {MANUAL_SUGGESTION}

---

> 本报告由 AI Auto-Dev 自动生成，完整代码变更请查看对应 PR。
