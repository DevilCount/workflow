#!/usr/bin/env python3
"""
parse-products.py - 解析 products.yaml 并输出指定字段

用法:
  python3 parse-products.py <产品名> [字段列表]
  python3 parse-products.py <产品名> product_info

字段列表: 逗号分隔，可选 name, url, branch, skill, tfs_project, description, source_path
默认: name,url,branch

输出: 管道分隔的文本，每行一个仓库

示例:
  python3 parse-products.py {产品名} name,url,branch
  # repo-name|http://...|develop

  python3 parse-products.py {产品名} name,branch,skill
  # repo-name|develop|backend-dev

  python3 parse-products.py {产品名} product_info
  # tfs_project: ...
  # default_skill: ...
  # default_branch: ...
"""

import sys
import os

REPO_FIELDS = ("name", "url", "branch", "skill", "tfs_project", "description", "source_path")
PRODUCT_FIELDS = ("tfs_project", "default_skill", "default_branch", "worktree")


def _parse_kv(text, repo):
    """解析 `key: "value"` 并写入 repo dict"""
    key, _, value = text.partition(":")
    key = key.strip()
    value = value.strip().strip('"').strip("'")
    if key in REPO_FIELDS:
        repo[key] = value


def parse_yaml_simple(filepath):
    """解析 products.yaml，返回 (repos_dict, meta_dict)"""

    # 优先使用 PyYAML（更健壮）
    try:
        import yaml
        with open(filepath, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data or "products" not in data:
            return {}, {}
        products_repos = {}
        products_meta = {}
        for pname, pconf in data.get("products", {}).items():
            if pconf is None:
                continue
            products_meta[pname] = {
                "tfs_project": pconf.get("tfs_project", ""),
                "default_skill": pconf.get("default_skill", ""),
                "default_branch": pconf.get("default_branch", ""),
                "worktree": pconf.get("worktree", False),
            }
            products_repos[pname] = pconf.get("repos", []) or []
        return products_repos, products_meta
    except ImportError:
        pass

    # Fallback: 手写解析器
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    products_repos = {}
    products_meta = {}
    current_product = None
    in_repos = False
    current_repo = {}

    for raw_line in lines:
        line = raw_line.rstrip("\n")
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(stripped)

        # 顶级 key（产品名），indent == 2
        if indent == 2 and stripped.endswith(":") and not stripped.startswith("-"):
            if current_product and current_repo:
                products_repos.setdefault(current_product, []).append(current_repo)
            current_product = stripped[:-1].strip()
            current_repo = {}
            in_repos = False
            continue

        # 产品级 key (indent == 4)
        if indent == 4 and current_product and ":" in stripped:
            if stripped == "repos:":
                if current_repo:
                    products_repos.setdefault(current_product, []).append(current_repo)
                in_repos = True
                current_repo = {}
                continue
            # 产品级字段
            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key in PRODUCT_FIELDS:
                products_meta.setdefault(current_product, {})[key] = value
            in_repos = False
            continue

        # repos 列表项 (indent == 6, 以 - 开头)
        if indent == 6 and in_repos and stripped.startswith("-"):
            if current_repo and current_repo.get("name"):
                products_repos.setdefault(current_product, []).append(current_repo)
            current_repo = {}
            rest = stripped[1:].strip()
            if ":" in rest:
                _parse_kv(rest, current_repo)
            continue

        # repo 属性 (indent >= 8)
        if indent >= 8 and in_repos and ":" in stripped:
            _parse_kv(stripped, current_repo)
            continue

    # 最后一个 repo
    if current_product and current_repo and current_repo.get("name"):
        products_repos.setdefault(current_product, []).append(current_repo)

    return products_repos, products_meta


def print_product_info(products_meta, product_name):
    """打印产品级字段"""
    if product_name not in products_meta:
        print(f"错误: 产品 '{product_name}' 未找到", file=sys.stderr)
        sys.exit(1)
    meta = products_meta[product_name]
    for key in PRODUCT_FIELDS:
        print(f"{key}: {meta.get(key, '')}")


def main():
    if len(sys.argv) < 2:
        print("用法: python3 parse-products.py <产品名> [字段列表|product_info]", file=sys.stderr)
        sys.exit(1)

    product_name = sys.argv[1]
    fields_str = sys.argv[2] if len(sys.argv) > 2 else "name,url,branch"

    # 定位 products.yaml
    script_dir = os.path.dirname(os.path.abspath(__file__))
    yaml_path = os.path.join(script_dir, "..", "templates", "products.yaml")

    products_repos, products_meta = parse_yaml_simple(yaml_path)

    if fields_str == "product_info":
        print_product_info(products_meta, product_name)
        return

    if product_name not in products_repos:
        print(f"错误: 产品 '{product_name}' 未找到", file=sys.stderr)
        sys.exit(1)

    fields = [f.strip() for f in fields_str.split(",")]

    for repo in products_repos[product_name]:
        values = [str(repo.get(f, "")) for f in fields]
        print("|".join(values))


if __name__ == "__main__":
    main()
