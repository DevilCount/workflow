#!/usr/bin/env python3
"""
register-product.py - 从本地仓库扫描结果注册新产品到 products.yaml

用法:
  python register-product.py --name <产品名> --repos '<JSON数组>'
  python register-product.py --name <产品名> --repos-file <文件路径>
"""

import json
import os
import re
import shutil
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(SCRIPT_DIR)
PRODUCTS_YAML = os.path.join(SKILL_DIR, "templates", "products.yaml")


def guess_skill(name: str) -> str:
    lower = name.lower()
    if any(kw in lower for kw in ("rdf", "pango")):
        return "rdf-dev"
    if any(kw in lower for kw in ("web", "frontend", "ui", "vue", "react", "ymer", "page", "spa")):
        return "frontend-dev"
    return "backend-dev"


def generate_product_yaml(product_name: str, tfs_project: str,
                          default_branch: str, repos: list) -> str:
    from collections import Counter
    skill_counts = Counter(r["skill"] for r in repos)
    default_skill = skill_counts.most_common(1)[0][0]

    lines = [
        f"\n  {product_name}:",
        f'    tfs_project: "{tfs_project}"',
        f'    default_skill: "{default_skill}"',
        f'    default_branch: "{default_branch}"',
        f"    change_limits:",
        f"      max_files: 20",
        f"      max_insertions: 500",
        "",
        "    repos:",
    ]

    for r in repos:
        lines += [
            f'      - name: "{r["name"]}"',
            f'        url: "{r["url"]}"',
            f'        branch: "{r["branch"]}"',
            f'        skill: "{r["skill"]}"',
            f'        tfs_project: "{r["tfs_project"]}"',
            f'        source_path: "{r["source_path"]}"',
            f'        description: ""',
            "",
        ]

    lines += [
        "    skill_routing:",
        '      "AI-BACKEND": "backend-dev"',
        '      "AI-FRONTEND": "frontend-dev"',
        '      "AI-RDF": "rdf-dev"',
        '      "AI-FULLSTACK":',
        '        - "backend-dev"',
        '        - "frontend-dev"',
    ]

    return "\n".join(lines)


def product_exists(yaml_path: str, product_name: str) -> bool:
    if not os.path.exists(yaml_path):
        return False
    with open(yaml_path, "r", encoding="utf-8") as f:
        return bool(re.search(rf"^  {re.escape(product_name)}:", f.read(), re.MULTILINE))


def main():
    import argparse
    parser = argparse.ArgumentParser(description="注册本地产品到 products.yaml")
    parser.add_argument("--name", required=True, help="产品名称")
    parser.add_argument("--repos", help="仓库 JSON 数组字符串")
    parser.add_argument("--repos-file", help="仓库 JSON 数组文件路径")
    args = parser.parse_args()

    if not args.repos and not args.repos_file:
        print("错误: 必须提供 --repos 或 --repos-file", file=sys.stderr)
        sys.exit(1)

    if args.repos_file:
        with open(args.repos_file, "r", encoding="utf-8") as f:
            repos = json.load(f)
    else:
        repos = json.loads(args.repos)

    if not repos:
        print("错误: 仓库列表为空", file=sys.stderr)
        sys.exit(1)

    # 补充默认 skill
    for r in repos:
        if "skill" not in r or not r["skill"]:
            r["skill"] = guess_skill(r["name"])

    product_name = args.name
    tfs_project = repos[0].get("tfs_project", "")
    default_branch = repos[0].get("branch", "master")

    # 确保 products.yaml 存在
    if not os.path.exists(PRODUCTS_YAML):
        with open(PRODUCTS_YAML, "w", encoding="utf-8") as f:
            f.write("products:\n")

    # 检查是否已存在
    if product_exists(PRODUCTS_YAML, product_name):
        print(f"警告: 产品 '{product_name}' 已存在，将覆盖", file=sys.stderr)

    # 备份
    bak = PRODUCTS_YAML + ".bak"
    shutil.copy2(PRODUCTS_YAML, bak)

    # 生成 YAML 并追加
    yaml_block = generate_product_yaml(product_name, tfs_project, default_branch, repos)
    with open(PRODUCTS_YAML, "a", encoding="utf-8") as f:
        f.write(yaml_block)
        f.write("\n")

    print(f"OK: 产品 '{product_name}' 已注册 ({len(repos)} 个仓库)")


if __name__ == "__main__":
    main()
