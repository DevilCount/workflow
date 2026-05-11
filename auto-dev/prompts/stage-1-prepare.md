## 执行流程

### Step 0 前置: 创建工作目录和日志文件

在执行任何操作之前，先创建工作目录和日志文件：
```bash
mkdir -p {WORK_DIR}/docs
LOG_FILE="{WORK_DIR}/docs/auto-dev-$(date '+%Y%m%d-%H%M%S').log"
touch "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [准备] 自动开发启动，需求 {DEMAND_ID}" >> "$LOG_FILE"
```

注意：此时 `{WORK_DIR}` 使用主 agent 传入的值（已在 Step 0 中计算好）。

### Step 0: MCP 连接验证

调用轻量级 MCP 工具验证服务可达：
```
mcp__tfs-mcp__tfs_get_current_collection()
```

如果失败，等待3秒重试一次。如果仍然失败，等待5秒重试第二次。3次都失败则返回失败结果。

### Step 1: 获取详情 + 产品匹配

**1.1 获取工作项详情**

```
mcp__tfs-mcp__tfs_get_workitem({ id: {DEMAND_ID}, embedImages: true })
```

**1.2 产品匹配**

读取字段 `Winning.Module.name` 的值，trim 前后空格，与 products.yaml 中的产品名称进行 **精确字符串匹配**。

- **字段为空**: 尝试从标题前缀推断（如标题以"产品名："开头 → 匹配对应产品名）
- **匹配失败**: 检查当前工作目录是否包含本地 TFS 仓库：
  ```bash
  bash SKILL_DIR/scripts/detect-local-repos.sh
  ```
  如果发现仓库：
  1. 读取 products.yaml 检查是否有产品配置与这些仓库匹配（通过 url 或 source_path）→ 匹配到则使用该产品继续
  2. products.yaml 为空（无任何产品配置）→ 调用注册脚本自动创建产品配置：
     ```bash
     bash SKILL_DIR/scripts/detect-local-repos.sh > /tmp/local-repos.json
     # 从工作项标题或 Winning.Module.name 推断产品名，无法推断时用仓库名前缀
     python SKILL_DIR/scripts/register-product.py --name "{推断的产品名}" --repos-file /tmp/local-repos.json
     ```
     注册成功 → 重新读取 products.yaml，使用新注册的产品继续
  3. products.yaml 非空但无匹配 + 无法自动注册 → 跳过
- **匹配成功**: 记录产品名，继续

**发送启动通知**：
```bash
bash SKILL_DIR/scripts/wechat-notify.sh start {产品名} {DEMAND_ID} "{DEMAND_TITLE}"
```

**跳过时执行**:
```
mcp__tfs-mcp__tfs_add_tags({DEMAND_ID}, "AI-SKIPPED")
mcp__tfs-mcp__tfs_add_comment({DEMAND_ID}, "AI自动开发跳过: 需求模块'{Winning.Module.name}'未匹配到已配置产品")
```
返回跳过结果 → 结束。

**设置需求状态为"活动"**：
```
mcp__tfs-mcp__tfs_change_state({ id: {DEMAND_ID}, state: "活动" })
```

如果状态变更失败（如已经是"活动"），记录警告但继续执行。

**计算工作目录 WORK_DIR**：

先检查产品的 base_path 和 worktree 配置：
```bash
BASE_PATH=$(python SKILL_DIR/scripts/parse-products.py {产品名} product_info | grep 'base_path:' | awk '{print $2}')
WORKTREE_MODE=$(python SKILL_DIR/scripts/parse-products.py {产品名} product_info | grep 'worktree:' | awk '{print $2}')
REPO_INFO=$(python SKILL_DIR/scripts/parse-products.py {产品名} name,source_path)
FIRST_SOURCE_PATH=$(echo "$REPO_INFO" | head -1 | cut -d'|' -f2)
```

根据模式计算 WORK_DIR：

- **有 base_path（推荐）**：
  - WORK_DIR = `{base_path}/auto-dev-{DEMAND_ID}`
  - 例如 base_path=`D:/代码/自助机(HSS)/01 自助机系统/V6.0` → WORK_DIR=`D:/代码/自助机(HSS)/01 自助机系统/V6.0/auto-dev-1931988`
- **worktree: true（兼容旧逻辑）**：
  - 有 source_path 且无 base_path：WORK_DIR = `dirname(dirname(source_path))` / `basename(dirname(source_path))` `_` `{DEMAND_ID}`
  - 无 source_path 且无 base_path：WORK_DIR = `~/auto/{产品名}/{DEMAND_ID}`
- **worktree: false（默认）**：
  - 有 source_path：WORK_DIR = source_path（直接在源仓库中工作）
  - 无 source_path：WORK_DIR = `~/tfs/{产品名}/{仓库名}`（仓库目录）

将计算出的 WORK_DIR 和 WORKTREE_MODE 保存为变量，后续所有步骤中使用。

### Step 2: 下载附件 + 确定仓库路由

**2.1 下载附件**

```
mcp__tfs-mcp__tfs_download_attachments({ id: {DEMAND_ID}, targetDir: "{WORK_DIR}/docs/" })
```

**2.2 确定仓库和技能路由**

根据标签决定处理哪些仓库：
- AI-BACKEND → repos 中 skill=backend-dev 的仓库
- AI-FRONTEND → repos 中 skill=frontend-dev 的仓库
- AI-RDF → repos 中 skill=rdf-dev 的仓库
- AI-FULLSTACK → 所有仓库，按各自 skill 路由
- 无技能标签 → 使用 default_skill

### Step 3: 准备开发环境

根据 WORKTREE_MODE 选择不同的准备方式：

**3A. worktree: false（默认）— 直接在源仓库创建 feature 分支**

对每个需要处理的仓库，执行以下步骤：

1. **进入源仓库目录**：
```bash
cd {source_path}
```

2. **安全检查**：检测当前分支，禁止从 feature 分支创建开发分支：
```bash
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" == feature/* ]]; then
  echo "BLOCKED: 当前已在 feature 分支 '$CURRENT_BRANCH' 上，不能从 feature 分支创建开发分支。请先切到非 feature 分支（如 develop_v5、master），然后重新运行。"
  # 记录错误日志并返回失败结果
fi
```
如果安全检查失败：**立即中止**，返回失败结果（FAIL_STEP: Step 3 安全检查）。不要尝试绕过。

3. **拉取最新代码**：
```bash
git fetch origin
```

4. **创建并切换到 feature 分支**（从 base_branch 创建）：
```bash
REPO_BRANCH=$(python SKILL_DIR/scripts/parse-products.py {产品名} name,branch | grep {仓库名} | cut -d'|' -f2)
git branch --no-track feature/{DEMAND_ID} origin/$REPO_BRANCH 2>&1 || \
git branch --no-track feature/{DEMAND_ID} $REPO_BRANCH 2>&1
git checkout feature/{DEMAND_ID}
```

5. **创建 docs 目录**：
```bash
mkdir -p {WORK_DIR}/docs
```

**3B. worktree: true — 使用 worktree 隔离**

**检查本地模式**：先用 parse-products 检查该产品是否有 source_path 配置：
```bash
python SKILL_DIR/scripts/parse-products.py {产品名} name,source_path
```

如果有任何 repo 的 source_path 非空且路径存在，则该产品为"本地模式"。

**本地模式**：跳过 init-repo.sh，直接创建 worktree：
```bash
bash SKILL_DIR/scripts/setup-worktree.sh create {产品名} {DEMAND_ID}
```

**标准模式**：执行完整流程：
```bash
bash SKILL_DIR/scripts/init-repo.sh {产品名}
bash SKILL_DIR/scripts/setup-worktree.sh create {产品名} {DEMAND_ID}
```

如果 setup-worktree.sh 失败，手动执行（注意 source_path）：
```bash
# 获取 source_path（如果有）
REPO_INFO=$(python SKILL_DIR/scripts/parse-products.py {产品名} name,branch,source_path)
# 解析对应仓库的 source_path，如果有则用它，否则用 ~/tfs/{产品名}/{仓库名}
cd {源仓库路径}
git fetch origin
git branch feature/{DEMAND_ID} origin/{base_branch}
git worktree add {WORK_DIR}/{仓库名} feature/{DEMAND_ID}
```

## 阶段完成

完成后追加日志：
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [准备] 阶段完成" >> {LOG_FILE}
```

输出阶段结果，DATA 中必须包含：
```
DATA:
  WORK_DIR={计算出的工作目录}
  LOG_FILE={日志文件路径}
  REPOS={repo1:skill1,repo2:skill2}
  PRODUCT={产品名}
  DEMAND_TITLE={实际需求标题}
```

DETAILS 中包含：
- 需求信息（ID、标题）
- 产品匹配结果
- 仓库列表和技能路由
- worktree 创建结果
- 阶段耗时
