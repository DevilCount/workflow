#!/bin/bash
set -e
# ============================================================
# init-repo.sh - 产品仓库初始化/更新脚本
# 用法: ./init-repo.sh <产品名称>
# 功能: 根据 products.yaml 拉取/更新所有仓库
# ============================================================

PRODUCT="${1:?用法: $0 <产品名称>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PRODUCTS_YAML="$SKILL_DIR/templates/products.yaml"
TFS_BASE="$HOME/tfs"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 解析 products.yaml（使用共用 Python 脚本）
parse_repos() {
    python "$SKILL_DIR/scripts/parse-products.py" "$1" "name,url,branch,source_path"
}

# 主流程
main() {
    if [ ! -f "$PRODUCTS_YAML" ]; then
        log_error "找不到产品配置: $PRODUCTS_YAML"
        exit 1
    fi

    PRODUCT_DIR="$TFS_BASE/$PRODUCT"
    mkdir -p "$PRODUCT_DIR"

    log_info "初始化产品: $PRODUCT"
    log_info "目标目录: $PRODUCT_DIR"
    log_info "---"

    REPOS=$(parse_repos "$PRODUCT")
    
    if [ -z "$REPOS" ]; then
        log_error "产品 '$PRODUCT' 未在 products.yaml 中找到，或没有配置仓库"
        exit 1
    fi

    SUCCESS=0
    FAIL=0

    while IFS='|' read -r name url branch source_path; do
        REPO_PATH="$PRODUCT_DIR/$name"

        # 如果有 source_path 且路径存在，跳过 clone/fetch
        if [ -n "$source_path" ] && [ -d "$source_path" ]; then
            log_info "跳过: $name (本地源: $source_path)"
            SUCCESS=$((SUCCESS + 1))
            echo "---"
            continue
        fi

        if [ -d "$REPO_PATH" ]; then
            log_info "更新: $name (git pull)"
            cd "$REPO_PATH"
            if git fetch --all 2>&1 | tail -1 && \
               git checkout "$branch" 2>&1 | tail -1 && \
               git pull origin "$branch" 2>&1 | tail -1; then
                SUCCESS=$((SUCCESS + 1))
            else
                log_warn "更新失败: $name (继续处理其他仓库)"
                FAIL=$((FAIL + 1))
            fi
        else
            log_info "克隆: $name ($branch)"
            cd "$PRODUCT_DIR"
            if git clone -b "$branch" "$url" "$name" 2>&1; then
                log_info "克隆成功: $name"
                SUCCESS=$((SUCCESS + 1))
            else
                log_error "克隆失败: $name"
                FAIL=$((FAIL + 1))
            fi
        fi
        echo "---"
    done <<< "$REPOS"

    echo ""
    log_info "完成: 成功 $SUCCESS, 失败 $FAIL"
}

main
