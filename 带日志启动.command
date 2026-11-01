#!/bin/sh
# SA-MP 带日志启动
#
# 用法：
#   双击本文件                          → 静默崩溃捕获（正常玩时日志几乎是空的）
#   终端里：./带日志启动.command font   → 抓字体请求（排查中文方块用）
#   终端里：./带日志启动.command seh    → 全量详细日志（会刷得很快，深度排查用）
#
# 日志写在 ~/samp-debug-<时间戳>[-font|-seh].log
set -u

BOTTLE="samp"
GAME='C:\GTA'
WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"

MODE="${1:-}"
case "$MODE" in
  font) CHANNELS="+timestamp,+font";               SUFFIX="-font"; FILTER=font  ;;
  seh)  CHANNELS="+timestamp,+seh,+unwind,+module"; SUFFIX="-seh";  FILTER=none  ;;
  *)    CHANNELS="+timestamp,+unwind,+module";      SUFFIX="";      FILTER=crash ;;
esac

# 重要：不能用 WINEDEBUG。
# CrossOver 的 bin/wine 是个 Perl 启动器，没传 --cx-log 时会执行
#     $opt_debugmsg = "-all" if (!defined $opt_debugmsg);
# 然后把 $ENV{WINEDEBUG} 覆盖成 -all —— 也就是"所有通道全关"。
# 结果就是 export WINEDEBUG=+font 完全无效（实测 +relay 都一条不输出）。
# 唯一有效的开关是命令行参数 --debugmsg。

# ---------- 崩溃模式：环形缓冲 ----------
# +unwind/+module 一开，正常玩一分钟就是 5 MB / 5 万行（实测 99.7% 是噪音），
# 终端刷得看不清，日志也没人愿意翻。
# 所以：正常行全部丢进内存里的环形缓冲，不写盘；只有出现崩溃特征时，
# 才把崩溃前最近 300 行有意义的内容 + 之后的所有输出一次性倒出来。
#
# 判据必须写全（"Unhandled exception" 而不是 "Unhandled"）：Wine 的常规
# fixme 里就有一句 "fixme:d3d:resource_check_usage Unhandled usage flags 0x20."，
# 用 "Unhandled" 会在开局几秒内误判成崩溃，然后整场日志原样输出（踩过）。
# 结果：崩了 → 上下文 + 完整回溯都在；没崩（含静默退出）→ 倒出最后 300 行。
#
# 为什么没崩也要倒出来：这个服务器有过**静默闪退**（进程直接消失、无对话框、
# 无崩溃特征，见 docs/issue-silent-exit.md）。那种情况下 crashed 永远不会被置位，
# 旧版本就只打一句"本次没有捕获到崩溃"，等于什么都没抓到（踩过）。
# 现在改成：没等到崩溃特征也把环形缓冲倒出来——静默退出的现场只能从"最后在做什么"里找线索。
CRASH_FILTER='
BEGIN { BUF = 300; n = 0; crashed = 0 }
{
  line = $0
  if (crashed) { print; next }
  if (line ~ /(Unhandled exception|Unhandled page fault|page fault on |Assertion failed|Backtrace:)/) {
    shown = 0
    for (i = n - BUF; i < n; i++) if (i >= 0) { print q[i % BUF]; shown++ }
    if (!shown) print "### 崩溃前没有可显示的业务日志（全是 unwind/module 噪音）###"
    crashed = 1
    print
    next
  }
  if (line ~ /:(err|warn):/) { print; next }
  if (line ~ /:trace:(module|unwind|loaddll|seh):/) next
  q[n % BUF] = line
  n++
}
END {
  if (!crashed) {
    printf("### 未捕获到崩溃特征（可能是静默退出，见 docs/issue-silent-exit.md）###\n")
    printf("### 下面是进程结束前最后 %d 行业务日志，看看最后在做什么：###\n", (n < BUF ? n : BUF))
    st = (n > BUF ? n - BUF : 0)
    for (i = st; i < n; i++) print q[i % BUF]
    printf("### 共缓冲 %d 行 ###\n", n)
  }
}'

# ---------- font 模式：只留三类字体记录 ----------
# +font 原始输出 144 MB / 205 万行（光启动 samp.exe），有用信息不到 1%。
#
# 这里踩过两个坑，都是"为了看得更清楚反而把游戏搞死"：
#
# 坑 1：做全局去重 `if (line in seen) next`，把 `select_font Chosen` 吃掉了——
#       同一个字面被选中多次时只留第一行，于是"公告牌那批请求到底创建成功没有"
#       根本看不出来。所以**不能**简单地按内容全局去重。
#
# 坑 2：那就干脆不去重？更糟。游戏每帧都会请求 `System` / `Tahoma` 这些自带 UI 字体，
#       以前被去重压成 1 行，不去重就是每秒几百行。实测 70 秒写了 3.5 MB / 3.3 万行，
#       awk → tee → 终端 这条链跟不上，游戏**阻塞在写日志上，直接卡死**（看着像 hang，
#       其实进程活着、没有崩溃、日志还在慢慢涨）。
#
# 现在两条一起用：
#   · 黑名单直接丢掉游戏自带 UI 的字体请求（它们不可能是公告牌用的字体）
#   · 其余每一条**最多保留 10 次**——既保住"首次出现"的配对关系，又把总量压住
# 结果：日志回到 200 KB 量级，且 `Chosen` 一条不少。
FONT_FILTER='
BEGIN { n = 0; LIMIT = 20000; CAP = 10 }
{
  if ($0 ~ /:d3dx:/) next

  # 游戏自带 UI 字体，每帧都请求，纯噪音
  if ($0 ~ /trace:font:font_SelectFont L"(System|Tahoma|Verdana|MS Sans Serif|Microsoft Sans Serif|GTAWEAPON3|SAMPAUX3)"/) next

  keep = 0
  if ($0 ~ /trace:font:(font_SelectFont L"|find_matching_face substituting|select_font Chosen)/) keep = 1
  else if ($0 ~ /(Unhandled exception|Unhandled page fault|page fault on |Assertion failed|Backtrace:)/) keep = 1
  if (!keep) next

  if (++seen[$0] > CAP) next
  if (n >= LIMIT) { if (n == LIMIT) { print "### 已达 " LIMIT " 行上限，后续被截断 ###"; n++ } next }
  print; n++
}
END { printf("### 字体记录共 %d 行 ###\n", n) }'

LOG="$HOME/samp-debug-$(date +%Y%m%d-%H%M%S)$SUFFIX.log"

# 必须设置中文 locale：否则 Wine 用非中文代码页，
# samp.exe 找不到中文路径下的 gta_sa.exe，会弹乱码框。
export LC_ALL=zh_CN.UTF-8
export LANG=zh_CN.UTF-8

case "$MODE" in
  font) DESC="抓字体请求（过滤后约 200 KB）" ;;
  seh)  DESC="全量详细日志（会刷得很快）" ;;
  *)    DESC="静默崩溃捕获（没崩就几乎没日志）" ;;
esac

echo "=============================================="
echo " 模式: $DESC"
echo " 通道: $CHANNELS"
echo " 日志文件: $LOG"
echo " 启动后请在服务器浏览器里选服务器，点「连接」。"
echo "=============================================="
echo

run_wine() {
  "$WINE" --bottle "$BOTTLE" --debugmsg "$CHANNELS" \
          --workdir "$GAME" --cx-app "$GAME\\samp.exe" 2>&1
}

case "$FILTER" in
  crash) run_wine | awk "$CRASH_FILTER" | tee "$LOG" ;;
  font)  run_wine | awk "$FONT_FILTER"  | tee "$LOG" ;;
  *)     run_wine | tee "$LOG" ;;
esac

echo
echo "=============================================="
echo " 游戏已退出。日志: $LOG"
if [ "$MODE" = "font" ]; then
  echo
  echo " 出现过的字体请求（按次数）："
  grep -ao 'font_SelectFont L"[^"]*", h=[-0-9]*, it=[0-9]*, weight=[0-9]*, PandF=[0-9a-f]*, charset=[0-9]*' "$LOG" 2>/dev/null \
    | sed 's/font_SelectFont //' | sort | uniq -c | sort -rn | head -20
  echo
  echo " 替换命中记录（按次数）："
  grep -ao 'substituting L"[^"]*",[0-9]* -> L"[^"]*",[0-9]*' "$LOG" 2>/dev/null | sort | uniq -c | sort -rn | head -10
  echo
  echo " 最终选中的字体（按次数）："
  grep -ao 'Chosen: L"[^"]*"' "$LOG" 2>/dev/null | sort | uniq -c | sort -rn | head -12
  echo
  echo " 请求 / 结果 发生顺序（前 50 行，便于对照）："
  echo "   注意：Chosen 只在「真的新建了一个字体对象」时出现，命中缓存则没有。"
  grep -aoE 'font_SelectFont L"[^"]*", h=[-0-9]+, it=[0-9]+, weight=[0-9]+, PandF=[0-9a-f]+, charset=[0-9]+|Chosen: L"[^"]*"' "$LOG" 2>/dev/null | head -50 | sed 's/^/   /'
fi
echo
if grep -qE "Unhandled exception|Unhandled page fault|page fault on |Assertion failed|Backtrace:" "$LOG" 2>/dev/null; then
  LN=$(grep -nE "Unhandled exception|Unhandled page fault|page fault on |Assertion failed|Backtrace:" "$LOG" | head -1 | cut -d: -f1)
  echo " ⚠️ 捕获到崩溃（日志第 $LN 行起），看上下文："
  echo "   sed -n '${LN},\$p' \"$LOG\" | head -60"
else
  echo " 未捕获到崩溃。"
fi
echo " 日志大小: $(du -h "$LOG" | cut -f1)"
echo "=============================================="
