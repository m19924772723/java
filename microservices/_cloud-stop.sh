#!/usr/bin/env bash
# youlai-cloud 全家桶停止：前端 9527 / gateway 9999 / auth 9000 / system 8800 / nacos 8848
export MSYS2_ARG_CONV_EXCL='*'
BASE="D:/code/workbuddy/workbuddy-project/java/microservices"
LOGS="$BASE/_cloud-logs"

port_pid() { netstat -ano 2>/dev/null | tr -d '\r' | awk -v pp=":$1" '$2 ~ (pp"$") && $4=="LISTENING" {print $5; exit}'; }

for spec in "9527 vue-admin" "9999 gateway" "9000 auth" "8800 system" "8848 nacos"; do
  set -- $spec; port=$1; name=$2
  pid=$(port_pid "$port")
  if [ -z "$pid" ]; then echo "[..] $name ($port) 未在运行"; continue; fi
  echo "[..] 结束 $name (PID $pid) …"
  taskkill /F /T /PID "$pid" 2>&1 | tr -d '\r' | sed 's/^/    /'
  i=0; while netstat -ano 2>/dev/null | tr -d '\r' | grep -q ":$port .*LISTENING" && [ $i -lt 12 ]; do sleep 1; i=$((i+1)); done
  netstat -ano 2>/dev/null | tr -d '\r' | grep -q ":$port .*LISTENING" && echo "[X] $name 仍在监听" || echo "[OK] $name 已停止（$port 释放）"
done
