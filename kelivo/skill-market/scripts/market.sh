#!/bin/sh
# skill-market for Kelivo: search, preview, install and remove SKILL.md skills.
# Needs: sh, curl or wget, tar-free (downloads file by file), jq.
# Sources: GitHub API first, jsDelivr CDN as fallback (often faster in mainland China).
set -u

SKILLS_DIR="${KELIVO_SKILLS_DIR:-/skills}"
SRC=github
UA="kelivo-skill-market"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$HERE/references/catalog.tsv"

die() { echo "错误: $*" >&2; exit 1; }

need() {
  command -v jq >/dev/null 2>&1 || die "缺少 jq。先运行: apk add jq curl  (Debian/Ubuntu: apt install -y jq curl)"
  if command -v curl >/dev/null 2>&1; then DL=curl
  elif command -v wget >/dev/null 2>&1; then DL=wget
  else die "缺少 curl 或 wget。先运行: apk add curl"; fi
}

get() { # get URL -> stdout
  if [ "$DL" = curl ]; then
    curl -fsSL --max-time 30 -A "$UA" ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$1"
  else
    wget -q -T 30 -U "$UA" -O - "$1"
  fi
}

get_file() { # get URL DEST
  mkdir -p "$(dirname "$2")"
  if [ "$DL" = curl ]; then curl -fsSL --max-time 60 -A "$UA" -o "$2" "$1"
  else wget -q -T 60 -U "$UA" -O "$2" "$1"; fi
}

# parse "owner/repo[/sub/path][@ref]" or a github.com URL
parse() {
  s="$1"
  s="${s#https://}"; s="${s#http://}"; s="${s#github.com/}"
  # github.com/o/r/tree/ref/path  or  /blob/ref/path/SKILL.md
  case "$s" in
    */tree/*|*/blob/*)
      OWNER="$(echo "$s" | cut -d/ -f1)"; REPO="$(echo "$s" | cut -d/ -f2)"
      REF="$(echo "$s" | cut -d/ -f4)"; SUB="$(echo "$s" | cut -d/ -f5-)" ;;
    *)
      ref=""; case "$s" in *@*) ref="${s##*@}"; s="${s%@*}";; esac
      OWNER="$(echo "$s" | cut -d/ -f1)"; REPO="$(echo "$s" | cut -d/ -f2)"
      SUB="$(echo "$s" | cut -d/ -f3-)"; REF="$ref" ;;
  esac
  SUB="${SUB%/}"; SUB="${SUB%SKILL.md}"; SUB="${SUB%/}"
  [ -n "$OWNER" ] && [ -n "$REPO" ] || die "看不懂这个地址: $1  (格式: owner/repo/路径 或 GitHub 链接)"
  if [ -z "$REF" ]; then
    REF="$(get "https://api.github.com/repos/$OWNER/$REPO" 2>/dev/null | jq -r '.default_branch // empty')"
    [ -n "$REF" ] || REF=main
  fi
}

# set FILES (every file path at REF, one per line) and SRC (github|jsdelivr)
list_files() {
  FILES="$(get "https://api.github.com/repos/$OWNER/$REPO/git/trees/$REF?recursive=1" 2>/dev/null \
        | jq -r '.tree[]? | select(.type=="blob") | .path' 2>/dev/null)"
  if [ -n "$FILES" ]; then SRC=github; return 0; fi
  FILES="$(get "https://data.jsdelivr.com/v1/packages/gh/$OWNER/$REPO@$REF?structure=flat" 2>/dev/null \
        | jq -r '.files[]?.name' 2>/dev/null | sed 's#^/##')"
  [ -n "$FILES" ] || die "读不到 $OWNER/$REPO@$REF 的文件列表（GitHub 和 jsDelivr 都失败）"
  SRC=jsdelivr
}

raw_url() { # path -> url
  if [ "${SRC:-github}" = jsdelivr ]; then echo "https://cdn.jsdelivr.net/gh/$OWNER/$REPO@$REF/$1"
  else echo "https://raw.githubusercontent.com/$OWNER/$REPO/$REF/$1"; fi
}

skill_name() { # read name from SKILL.md frontmatter on stdin
  awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} /^name:/{sub(/^name:[ \t]*/,"");gsub(/["'\'']/,"");print;exit}'
}
skill_desc() {
  awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} /^description:/{sub(/^description:[ \t]*/,"");print;exit}'
}

cmd_search() {
  q="$*"; [ -n "$q" ] || die "用法: market.sh search 关键词"
  echo "== 精选目录 =="
  grep -i -- "$q" "$CATALOG" 2>/dev/null | awk -F'\t' '{printf "  %s\t%s\n",$1,$2}' || true
  echo "== GitHub（topic: agent-skills / claude-skills）=="
  enc="$(printf %s "$q" | jq -sRr @uri)"
  for t in agent-skills claude-skills; do
    get "https://api.github.com/search/repositories?q=$enc+topic:$t&sort=stars&per_page=8" 2>/dev/null \
      | jq -r '.items[]? | "  \(.full_name)\t★\(.stargazers_count)\t\(.description // "" | .[0:80])"'
  done | sort -u
  echo "提示: 用 'market.sh list owner/repo' 看仓库里有哪些技能。"
}

cmd_list() {
  parse "$1"
  list_files
  echo "$FILES" | grep -E '(^|/)SKILL\.md$' | while read -r p; do
    d="$(dirname "$p")"; [ "$d" = . ] && d=""
    md="$(get "$(raw_url "$p")" 2>/dev/null)"
    n="$(printf %s "$md" | skill_name)"; desc="$(printf %s "$md" | skill_desc | cut -c1-90)"
    echo "  $OWNER/$REPO${d:+/$d}	${n:-?}	$desc"
  done
}

cmd_show() {
  parse "$1"
  p="${SUB:+$SUB/}SKILL.md"
  get "https://raw.githubusercontent.com/$OWNER/$REPO/$REF/$p" 2>/dev/null \
    || get "https://cdn.jsdelivr.net/gh/$OWNER/$REPO@$REF/$p" || die "找不到 $p"
}

cmd_install() {
  parse "$1"
  list_files
  if [ -n "$SUB" ]; then sel="$(echo "$FILES" | grep -E "^$SUB/")"; else sel="$FILES"; fi
  echo "$sel" | grep -qE "^${SUB:+$SUB/}SKILL\.md$" \
    || die "$OWNER/$REPO/${SUB} 下没有 SKILL.md。先用 list 找到技能所在目录。"
  n="$(get "$(raw_url "${SUB:+$SUB/}SKILL.md")" | skill_name)"
  [ -n "$n" ] || n="$(basename "${SUB:-$REPO}")"
  n="$(echo "$n" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-\n' '-' | cut -c1-64)"
  dest="$SKILLS_DIR/$n"
  [ -e "$dest" ] && [ "${FORCE:-0}" != 1 ] && die "已存在 $dest。要覆盖请加 FORCE=1"
  count=$(echo "$sel" | grep -c .)
  [ "$count" -le 200 ] || die "文件太多（$count 个），不像单个技能，请指定子目录"
  tmp="$SKILLS_DIR/.tmp-$n.$$"; rm -rf "$tmp"; mkdir -p "$tmp"
  # supporting files first, SKILL.md last (Kelivo rescans after shell commands)
  echo "$sel" | grep -vE "^${SUB:+$SUB/}SKILL\.md$" | while read -r p; do
    [ -n "$p" ] || continue
    rel="${p#$SUB/}"; [ -z "$SUB" ] && rel="$p"
    case "$rel" in .git/*|.github/*) continue;; esac
    get_file "$(raw_url "$p")" "$tmp/$rel" || { echo "下载失败: $p" >&2; exit 1; }
  done || { rm -rf "$tmp"; die "安装中断"; }
  get_file "$(raw_url "${SUB:+$SUB/}SKILL.md")" "$tmp/SKILL.md" || { rm -rf "$tmp"; die "SKILL.md 下载失败"; }
  printf 'source: %s/%s%s@%s\nvia: %s\n' "$OWNER" "$REPO" "${SUB:+/$SUB}" "$REF" "$SRC" > "$tmp/.market-source"
  rm -rf "$dest"; mv "$tmp" "$dest"
  echo "已安装: $n -> $dest  (来源 $SRC)"
  echo "kelivo://skills/$n/SKILL.md"
}

cmd_installed() {
  for d in "$SKILLS_DIR"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    n="$(basename "$d")"; src="$(sed -n 's/^source: //p' "$d/.market-source" 2>/dev/null)"
    echo "  $n	${src:-手动/内置}"
  done
}

cmd_remove() {
  n="$1"; d="$SKILLS_DIR/$n"
  [ -f "$d/.market-source" ] || die "$n 不是用 skill-market 装的，不删除（内置或手动导入的请在 设置→技能 里管理）"
  rm -rf "$d" && echo "已删除: $n"
}

cmd_update() {
  n="$1"; d="$SKILLS_DIR/$n"
  src="$(sed -n 's/^source: //p' "$d/.market-source" 2>/dev/null)"
  [ -n "$src" ] || die "$n 没有来源记录，无法更新"
  FORCE=1 cmd_install "${src%@*}"
}

need
c="${1:-help}"; [ $# -gt 0 ] && shift
case "$c" in
  search) cmd_search "$@";;
  list) [ $# -ge 1 ] || die "用法: market.sh list owner/repo"; cmd_list "$1";;
  show) [ $# -ge 1 ] || die "用法: market.sh show owner/repo/路径"; cmd_show "$1";;
  install) [ $# -ge 1 ] || die "用法: market.sh install owner/repo/路径"; cmd_install "$1";;
  installed) cmd_installed;;
  remove) [ $# -ge 1 ] || die "用法: market.sh remove 技能名"; cmd_remove "$1";;
  update) [ $# -ge 1 ] || die "用法: market.sh update 技能名"; cmd_update "$1";;
  *) cat <<H
用法: sh market.sh <命令>
  search <关键词>          搜索精选目录和 GitHub
  list <owner/repo>        列出仓库里所有技能
  show <owner/repo/路径>   预览 SKILL.md
  install <owner/repo/路径|GitHub链接>  安装到 $SKILLS_DIR
  installed                已安装列表
  update <技能名>          按来源重新安装
  remove <技能名>          删除（只删本工具装的）
环境变量: KELIVO_SKILLS_DIR（默认 /skills）、GITHUB_TOKEN（可选，提高限额）、FORCE=1（覆盖）
H
  ;;
esac
