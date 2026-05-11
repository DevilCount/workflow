#!/bin/bash
# ============================================================
# wechat-notify.sh - 企业微信 Webhook 通知（shell 入口）
# 委托给 wechat-notify.py 执行
#
# 用法:
#   ./wechat-notify.sh <消息类型> <产品> <需求号> [标题] [扩展JSON文件]
# 消息类型: start | success | fail | progress | summary
# ============================================================

MSG_TYPE="${1:?用法: $0 start|success|fail|progress|summary <产品> <需求号> [标题] [扩展JSON文件]}"
PRODUCT="${2:-未知产品}"
TASK_ID="${3:-未知}"
TITLE="${4:-}"
EXT_FILE="${5:-}"

# 企业微信 Webhook URL
WECHAT_WEBHOOK="${WECHAT_WEBHOOK_URL:-}"

if [ -z "$WECHAT_WEBHOOK" ]; then
    ENV_FILE="$(cd "$(dirname "$0")" && pwd)/../config.env"
    [ -f "$ENV_FILE" ] && source "$ENV_FILE"
    WECHAT_WEBHOOK="${WECHAT_WEBHOOK_URL:-}"
fi

if [ -z "$WECHAT_WEBHOOK" ]; then
    echo "[通知] 未配置企微Webhook，跳过通知"
    exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python "$SCRIPT_DIR/wechat-notify.py" \
    "$MSG_TYPE" "$PRODUCT" "$TASK_ID" "$TITLE" "$TIMESTAMP" "$WECHAT_WEBHOOK" "$EXT_FILE"
