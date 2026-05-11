# products.yaml 配置说明

## 配置文件

| 文件 | 用途 |
|------|------|
| `templates/products.yaml` | 实际使用的配置（包含真实产品数据） |
| `templates/products-template.yaml` | 纯模板（新增产品时复制参考） |

## 配置结构

```yaml
products:
  产品名称:
    worktree: false              # false=直接在源仓库开发（默认）, true=worktree隔离模式
    tfs_project: "TFS项目路径"
    default_skill: "backend-dev"
    default_branch: "develop"
    base_path: "D:/代码/产品名/版本号"  # 可选，auto-dev工作目录基础路径（推荐）
    change_limits:                # 可选
      max_files: 20
      max_insertions: 500
    repos:
      - name: "仓库名"
        url: "git clone URL"
        branch: "分支名"
        skill: "backend-dev"
        tfs_project: "TFS项目路径"
        description: "仓库说明"
    skill_routing:
      "AI-BACKEND": "backend-dev"
      "AI-FRONTEND": "frontend-dev"
      "AI-RDF": "rdf-dev"
      "AI-FULLSTACK":
        - "backend-dev"
        - "frontend-dev"
```

## 新增产品

**方式一：使用脚本（推荐）**
```bash
python SKILL_DIR/scripts/add-product.py
```

**方式二：手动配置**
1. 参考 `templates/products-template.yaml` 的格式
2. 将新产品配置追加到 `templates/products.yaml`

## 常见问题

### Q: 产品名匹配不上怎么办？
A: auto-dev 会列出所有已配置的产品名让用户选择。

### Q: 需求涉及多个产品怎么办？
A: Phase1 暂不支持，需要拆成多个需求分别处理。

### Q: 开发过程中出错怎么办？
A: auto-dev 会保留 worktree，用户可以手动进入目录继续开发。

### Q: 如何清理已完成的 worktree？
```bash
bash SKILL_DIR/scripts/setup-worktree.sh remove {产品名} 1506090
```

### Q: worktree: false 和 true 有什么区别？
A: `worktree: false`（默认）直接在源仓库目录中创建 feature 分支开发，开发完成后保留分支和代码，适合首次使用和需要手动调试的场景。`worktree: true` 使用 git worktree 为每个需求创建隔离工作目录，适合全自动托管场景。

### Q: 企微通知没收到？
A: 检查 `WECHAT_WEBHOOK_URL` 环境变量是否配置。未配置时脚本会跳过通知，不影响主流程。

### Q: change_limits 改动量阈值怎么配？
A: 可选字段，控制单个需求的最大改动规模，防止 AI 过度修改。未配置时默认 `max_files: 20, max_insertions: 500`。任一指标超标（OR 关系）会跳过该需求并标记 `AI-SKIPPED`。

### Q: base_path 和 worktree/source_path 有什么区别？
A: `base_path` 是 auto-dev 工作目录的基础路径（推荐配置），格式为 `{base_path}/auto-dev-{需求号}`。例如 `D:/代码/自助机(HSS)/01 自助机系统/V6.0` 会生成 `D:/代码/自助机(HSS)/01 自助机系统/V6.0/auto-dev-1931988`。未配置 `base_path` 时，会回退到旧逻辑：使用 `source_path` 的父目录或 `~/auto/{产品名}/`。
