#!/usr/bin/env bash
# =============================================================================
# youlai-cloud 微服务全家桶常驻启动（Spring Cloud Alibaba + 前后端分离）
#   nacos(8848) -> gateway(9999) / auth(9000) / system(8800) -> 前端 vue-admin(9527)
#   前置：MySQL 3306（youlai_cloud + oauth2_server 库）、Redis 6379
# =============================================================================
set -u
BASE="D:/code/workbuddy/workbuddy-project/java/microservices"
CLOUD="$BASE/youlai-cloud"
LOGS="$BASE/_cloud-logs"
PIDS="$CLOUD/../_cloud-pids"
mkdir -p "$LOGS" "$PIDS"

JAVA21="D:/code/environment/jdk21/jdk-21.0.12.1+1"
JAVA="$JAVA21/bin/java.exe"
NACOS="D:/code/environment/nacos"
STUB=""
export MSYS2_ARG_CONV_EXCL='*'

port_pid() { netstat -ano 2>/dev/null | tr -d '\r' | awk -v pp=":$1" '$2 ~ (pp"$") && $4=="LISTENING" {print $5; exit}'; }
port_up()  { [ -n "$(port_pid "$1")" ]; }
http_code(){ curl -s --noproxy '*' -o /dev/null -m 4 -w "%{http_code}" "http://127.0.0.1:$1$2" 2>/dev/null; }
ok(){ echo "[OK] $*"; }
info(){ echo "[..] $*"; }
warn(){ echo "[!] $*"; }
err(){ echo "[X] $*"; }

# 0. 依赖服务
if ! port_up 6379; then
  info "拉起 Redis …"
  nohup "D:/code/environment/Redis/redis-server.exe" --port 6379 > "$LOGS/redis.log" 2>&1 < /dev/null &
  sleep 2
fi
port_up 6379 && ok "Redis 6379" || warn "Redis 未起"
port_up 3306 && ok "MySQL 3306" || warn "MySQL 3306 未运行（youlai 需要它）"

# 1. nacos
if port_up 8848; then ok "nacos 8848 已在运行"; else
  info "启动 nacos standalone …"
  ( cd "$NACOS" && JAVA_HOME="$JAVA21" SERVER_PORT=8848 nohup "$NACOS/bin/startup.cmd" -m standalone > "$LOGS/nacos.log" 2>&1 < /dev/null & echo $! > "$PIDS/nacos.pid" )
  i=0; while ! port_up 8848 && [ $i -lt 60 ]; do sleep 2; i=$((i+1)); done
  port_up 8848 && ok "nacos 8848 就绪" || { err "nacos 启动失败，见 $LOGS/nacos.log"; exit 1; }
fi

# 2. 三个微服务（串行启动：auth 完全就绪后 gateway 才能拉到 OIDC 元数据，auth 冷启动约 90s）
#    每个服务显式 SERVER_PORT=$port：防沙箱/环境残留 SERVER_PORT 随机值覆盖配置（61471 坑）
launch_svc() { # $1=名称 $2=端口 $3=jar路径
  if port_up "$2"; then ok "youlai-$1 $2 已在运行"; return 0; fi
  if [ ! -f "$3" ]; then err "找不到 youlai-$1 的 jar: $3"; return 1; fi
  info "启动 youlai-$1（$2）…"
  ( cd "$CLOUD" && SERVER_PORT=$2 nohup "$JAVA" -Dfile.encoding=UTF-8 -Dspring.cloud.nacos.discovery.ip=127.0.0.1 -jar "$3" > "$LOGS/$1.log" 2>&1 < /dev/null & echo $! > "$PIDS/$1.pid" )
  i=0; while ! port_up "$2" && [ $i -lt 90 ]; do sleep 2; i=$((i+1)); done
  port_up "$2" && ok "youlai-$1 $2 就绪" || err "youlai-$1 $2 未就绪（日志 $LOGS/$1.log）"
}
launch_svc auth    9000 "$CLOUD/youlai-auth/target/youlai-auth.jar"
launch_svc system  8800 "$CLOUD/youlai-system/system-boot/target/system-boot.jar"
launch_svc gateway 9999 "$CLOUD/youlai-gateway/target/youlai-gateway.jar"

# 4. 前端 dev server（9527）
if [ -d "$CLOUD/vue-admin/node_modules" ]; then
  if ! port_up 9527; then
    info "启动前端 vite dev（9527）…"
    ( cd "$CLOUD/vue-admin" && nohup pnpm dev > "$LOGS/vue-admin.log" 2>&1 < /dev/null & echo $! > "$PIDS/vue-admin.pid" )
    i=0; while ! port_up 9527 && [ $i -lt 45 ]; do sleep 2; i=$((i+1)); done
    port_up 9527 && ok "前端 9527 就绪 http://localhost:9527" || err "前端未就绪，见 $LOGS/vue-admin.log"
  else ok "前端 9527 已在运行"; fi
else
  warn "前端依赖未安装（node_modules 不存在），跳过前端；先跑 pnpm install"
fi

echo
echo "========== youlai-cloud 启动完成 =========="
echo " 前端        http://localhost:9527  (admin / 123456)"
echo " 网关        http://localhost:9999"
echo " 认证中心    http://localhost:9000"
echo " 系统服务    http://localhost:8800"
echo " nacos 控制台 http://localhost:8848/nacos"
echo "==========================================="

while true; do sleep 30; done
