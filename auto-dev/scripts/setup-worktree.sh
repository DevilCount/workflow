#!/bin/bash
# ============================================================
# setup-worktree.sh - Git Worktree 管理脚本
# 用法: 
#   ./setup-worktree.sh create <产品> <需求号> [仓库列表]
#   ./setup-worktree.sh remove  <产品> <需求号>
#   ./setup-worktree.sh list    <产品>
# ============================================================

set -e

ACTION="${1:?用法: $0 create|remove|list <产品> <需求号>}"
PRODUCT="${2:-}"
TASK_ID="${3:-}"
REPOS="${4:-all}"          # 指定仓库，逗号分隔，默认 all

TFS_BASE="$HOME/tfs"
AUTO_BASE="$HOME/auto"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PRODUCTS_YAML="$SKILL_DIR/templates/products.yaml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

# 根据 source_path 和需求号计算 worktree 工作目录
# 例如: source_path=/f/work-space/tenant/mdm-group/winning-group-mdm, task_id=1506090
#   → /f/work-space/tenant/mdm-group_1506090
compute_work_dir() {
    local source_path="$1"
    local task_id="$2"
    local parent_path
    parent_path=$(dirname "$source_path")
    local parent_name
    parent_name=$(basename "$parent_path")
    local grandparent
    grandparent=$(dirname "$parent_path")
    echo "$grandparent/${parent_name}_${task_id}"
}

# 从 products.yaml 获取仓库列表（使用共用 Python 脚本）
get_repos() {
    python "$SKILL_DIR/scripts/parse-products.py" "$1" "name,branch,skill,source_path"
}

# 创建 worktree
do_create() {
    local product="$PRODUCT"
    local task_id="$TASK_ID"
    local repos_filter="$REPOS"

    if [ -z "$product" ] || [ -z "$task_id" ]; then
        log_error "create 需要: <产品> <需求号>"
        exit 1
    fi

    log_info "创建 worktree: $product / $task_id"
    echo ""

    # 获取仓库列表
    local ALL_REPOS
    ALL_REPOS=$(get_repos "$product")

    if [ -z "$ALL_REPOS" ]; then
        log_error "未找到产品 '$product' 的仓库配置"
        exit 1
    fi

    local SUCCESS=0 FAIL=0 CREATED=0
    local WORK_DIR=""  # 记录首个 work_dir，用于摘要输出

    while IFS='|' read -r repo_name repo_branch repo_skill source_path; do
        # 过滤仓库
        if [ "$repos_filter" != "all" ]; then
            local match=0
            IFS=',' read -ra FILTER_ARR <<< "$repos_filter"
            for f in "${FILTER_ARR[@]}"; do
                if [ "$f" = "$repo_name" ]; then match=1; break; fi
            done
            if [ "$match" -eq 0 ]; then
                log_warn "跳过: $repo_name (不在指定列表中)"
                continue
            fi
        fi

        local source_repo="${source_path:-$TFS_BASE/$product/$repo_name}"

        # 根据 source_path 计算 worktree 工作目录
        local work_dir
        if [ -n "$source_path" ] && [ -d "$source_path" ]; then
            work_dir=$(compute_work_dir "$source_path" "$task_id")
        else
            work_dir="$AUTO_BASE/$product/$task_id"
        fi
        [ -z "$WORK_DIR" ] && WORK_DIR="$work_dir"

        local worktree_path="$work_dir/$repo_name"
        local feature_branch="feature/$task_id"

        if [ ! -d "$source_repo" ]; then
            log_error "源仓库不存在: $source_repo (请先运行 init-repo.sh)"
            FAIL=$((FAIL + 1))
            continue
        fi

        # 检查 worktree 是否已存在
        if [ -d "$worktree_path" ]; then
            log_warn "已存在: $worktree_path (跳过)"
            SUCCESS=$((SUCCESS + 1))
            continue
        fi

        log_step "创建 worktree: $repo_name"
        log_info "  源仓库: $source_repo"
        log_info "  分支: $feature_branch (base: $repo_branch)"
        log_info "  目标: $worktree_path"

        mkdir -p "$work_dir"
        cd "$source_repo"

        # 确保 base 分支是最新的
        git fetch origin 2>&1 | tail -1 || true

        # 创建 feature 分支（从 base 分支）
        if git show-ref --verify --quiet "refs/heads/$feature_branch"; then
            log_warn "  分支已存在: $feature_branch"
        else
            git branch --no-track "$feature_branch" "origin/$repo_branch" 2>&1 || \
            git branch --no-track "$feature_branch" "$repo_branch" 2>&1
            log_info "  分支已创建: $feature_branch"
        fi

        # 创建 worktree
        if git worktree add "$worktree_path" "$feature_branch" 2>&1; then
            log_info "  worktree 创建成功"
            CREATED=$((CREATED + 1))
            SUCCESS=$((SUCCESS + 1))
        else
            log_error "  worktree 创建失败"
            FAIL=$((FAIL + 1))
        fi
        echo ""
    done <<< "$ALL_REPOS"

    # 输出摘要
    echo "===================================="
    log_info "Worktree 创建完成"
    echo "  产品: $product"
    echo "  需求号: $task_id"
    echo "  成功: $SUCCESS (新建: $CREATED)"
    echo "  失败: $FAIL"
    echo "  工作目录: $WORK_DIR"
    echo "===================================="
}

# 删除 worktree
do_remove() {
    local product="$PRODUCT"
    local task_id="$TASK_ID"

    log_info "清理 worktree: $product / $task_id"

    # 获取仓库列表
    local ALL_REPOS
    ALL_REPOS=$(get_repos "$product")

    if [ -z "$ALL_REPOS" ]; then
        log_error "未找到产品 '$product' 的仓库配置"
        exit 1
    fi

    local -A WORK_DIRS  # 跟踪需要清理的 work_dir（去重）

    while IFS='|' read -r repo_name repo_branch repo_skill source_path; do
        local source_repo="${source_path:-$TFS_BASE/$product/$repo_name}"

        # 计算 work_dir
        local work_dir
        if [ -n "$source_path" ] && [ -d "$source_path" ]; then
            work_dir=$(compute_work_dir "$source_path" "$task_id")
        else
            work_dir="$AUTO_BASE/$product/$task_id"
        fi

        local wt_dir="$work_dir/$repo_name"
        if [ ! -d "$wt_dir" ]; then
            log_warn "  跳过: $repo_name (worktree 不存在)"
            continue
        fi

        WORK_DIRS["$work_dir"]=1

        # 竞态保护：检查目录下是否有正在运行的进程
        local running_pids
        if command -v lsof &>/dev/null; then
            running_pids=$(lsof +D "$wt_dir" 2>/dev/null | grep -v "^COMMAND" | awk '{print $2}' | sort -u)
        else
            running_pids=$(powershell -Command "Get-Process git -ErrorAction SilentlyContinue | Where-Object { \$_.Path -like \"$(cygpath -w "$wt_dir" 2>/dev/null || echo "$wt_dir")*\" } | Select-Object -ExpandProperty Id" 2>/dev/null | tr -d '\r')
        fi
        if [ -n "$running_pids" ]; then
            log_error "目录下有活跃进程，拒绝删除（PID: $running_pids）"
            log_error "请先停止相关进程再执行 remove"
            exit 1
        fi

        log_info "  清理: $repo_name"
        if [ -d "$source_repo" ]; then
            cd "$source_repo"
            git worktree remove "$wt_dir" --force 2>&1 || log_warn "  worktree remove 失败"
            git branch -D "feature/$task_id" 2>/dev/null || true
        fi
    done <<< "$ALL_REPOS"

    # 删除工作目录
    for wd in "${!WORK_DIRS[@]}"; do
        if [ -d "$wd" ]; then
            rm -rf "$wd"
            log_info "已删除: $wd"
        fi
    done
}

# 列出 worktree
do_list() {
    local product="$PRODUCT"

    # 获取仓库列表以确定 base 目录
    local ALL_REPOS
    ALL_REPOS=$(get_repos "$product")

    if [ -z "$ALL_REPOS" ]; then
        log_error "未找到产品 '$product' 的仓库配置"
        exit 1
    fi

    # 收集需要扫描的目录（去重）
    local -A SCAN_DIRS
    while IFS='|' read -r repo_name repo_branch repo_skill source_path; do
        if [ -n "$source_path" ] && [ -d "$source_path" ]; then
            local parent_path
            parent_path=$(dirname "$source_path")
            local parent_name
            parent_name=$(basename "$parent_path")
            local grandparent
            grandparent=$(dirname "$parent_path")
            SCAN_DIRS["$grandparent/$parent_name"]="$parent_name"
        fi
    done <<< "$ALL_REPOS"

    # 始终也扫描传统路径
    SCAN_DIRS["$AUTO_BASE/$product"]="$product"

    log_info "产品 '$product' 的 worktree 列表:"
    echo ""

    local found=0
    for scan_path in "${!SCAN_DIRS[@]}"; do
        local parent_name="${SCAN_DIRS[$scan_path]}"
        # 扫描 {parent_name}_* 模式的目录
        for task_dir in "${scan_path%/*}/${parent_name}"_*/; do
            [ -d "$task_dir" ] || continue
            # 提取需求号: {parent_name}_{task_id} → task_id
            local dir_name="$(basename "$task_dir")"
            local task_id="${dir_name#${parent_name}_}"
            # 跳过非数字后缀（可能误匹配其他目录）
            [[ "$task_id" =~ ^[0-9]+$ ]] || continue

            local repo_count=$(find "$task_dir" -maxdepth 1 -mindepth 1 -type d | wc -l)
            echo "  $task_id ($repo_count 个仓库)"

            for repo_dir in "$task_dir"/*/; do
                [ -d "$repo_dir" ] || continue
                local repo_name="$(basename "$repo_dir")"
                cd "$repo_dir"
                local branch="$(git branch --show-current 2>/dev/null || echo 'unknown')"
                local status="$(git status --short 2>/dev/null | wc -l)"
                echo "    - $repo_name [$branch] ${status} changes"
            done
            echo ""
            found=1
        done
    done

    if [ "$found" -eq 0 ]; then
        log_info "暂无 worktree"
    fi
}

case "$ACTION" in
    create) do_create ;;
    remove) do_remove ;;
    list)   do_list ;;
    *)
        echo "用法: $0 create|remove|list <产品> [需求号] [仓库列表]"
        echo ""
        echo "  create <产品> <需求号> [仓库]  - 创建 worktree"
        echo "  remove <产品> <需求号>         - 删除 worktree"
        echo "  list   <产品>                  - 列出所有 worktree"
        echo ""
        echo "示例:"
        echo "  $0 create {产品名} 1506090"
        echo "  $0 create {产品名} 1506090 repo1,repo2"
        echo "  $0 remove {产品名} 1506090"
        echo "  $0 list   {产品名}"
        exit 1
        ;;
esac
