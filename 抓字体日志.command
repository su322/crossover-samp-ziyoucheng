#!/bin/sh
# 抓字体日志（双击即用）
#
# 等价于在终端里执行：
#   ./带日志启动.command font
#
# 启动后请照常进服务器，走到那块公告牌前站两秒，然后退出游戏。
# 日志会写到 ~/samp-debug-<时间戳>-font.log
set -u

cd "$(dirname "$0")" || exit 1

echo "=============================================="
echo " 抓字体日志模式"
echo " 通道: +timestamp,+unwind,+module,+font,+d3dx"
echo " 崩溃回溯仍然保留（+unwind,+module 都在）。"
echo "=============================================="

if pgrep -f 'gta_sa\.exe|samp\.exe' >/dev/null 2>&1; then
  echo
  echo " ⚠️  检测到游戏已经在运行。"
  echo "    请先完全退出游戏（不要只关窗口），再双击本文件。"
  echo "    否则新的字体日志抓不到东西。"
  echo
  printf " 按回车关闭窗口…"
  read -r _
  exit 1
fi

./带日志启动.command font

echo
echo "=============================================="
echo " 日志已保存在 ~/ 下，文件名以 -font.log 结尾。"
echo " 把文件名告诉排查的人即可。"
echo "=============================================="
printf " 按回车关闭窗口…"
read -r _
