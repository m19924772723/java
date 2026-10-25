#!/usr/bin/env bash
# =============================================================================
# Java 项目统一启停引擎
#   用法: run.sh <项目key> start|stop|status|restart
#   项目目录下的 start.cmd / stop.cmd / start.sh / stop.sh 都是本脚本的薄壳
# 约定: 日志 _run/logs/<key>.log   PID _run/pids/<key>.pid
# =============================================================================
set -u

BASE="D:/code/workbuddy/workbuddy-project/java"
RUN="$BASE/_run"
LOGS="$RUN/logs"
PIDS="$RUN/pids"
mkdir -p "$LOGS" "$PIDS"

JDK21="D:/code/environment/jdk21/jdk-21.0.12.1+1"
JDK17="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"
JAVA="$JDK21/bin/java.exe"
JAVAC="$JDK21/bin/javac.exe"
# 注意：必须用 mvn.cmd —— bash 版 mvn 与 MSYS2_ARG_CONV_EXCL='*' 冲突，
# 会导致 java 收到 /d/... 这种 POSIX 路径，报 ClassNotFoundException: plexus Launcher
MVN="D:/code/environment/apache-maven-3.9.9/bin/mvn.cmd"
REDIS_CLI="D:/code/environment/Redis/redis-cli.exe"
REDIS_SRV="D:/code/environment/Redis/redis-server.exe"
LIBS="$BASE/_libs"
DEMOS="$BASE/_demos"
export MSYS2_ARG_CONV_EXCL='*'

C_OK="\033[32m"; C_ERR="\033[31m"; C_WARN="\033[33m"; C_DIM="\033[90m"; C_END="\033[0m"
ok()   { printf "${C_OK}[OK]${C_END} %s\n" "$*"; }
info() { printf "${C_DIM}[..]${C_END} %s\n" "$*"; }
warn() { printf "${C_WARN}[!]${C_END} %s\n" "$*"; }
err()  { printf "${C_ERR}[X]${C_END} %s\n" "$*"; }

# ---------- 基础工具 ----------
port_pid() {  # 返回监听该端口的 PID
  netstat -ano 2>/dev/null | tr -d '\r' \
    | awk -v pp=":$1" '$2 ~ (pp"$") && $4=="LISTENING" {print $5; exit}'
}
port_up() { [ -n "$(port_pid "$1")" ]; }

http_code() { curl -s --noproxy '*' -o /dev/null -m 4 -w "%{http_code}" "http://127.0.0.1:$1/" 2>/dev/null; }

wait_port() {  # wait_port <port> <秒> [http]
  local p="$1" t="${2:-40}" mode="${3:-http}" i=0
  while [ "$i" -lt "$t" ]; do
    if port_up "$p"; then
      ok "端口 $p 已就绪"
      [ "$mode" = "http" ] && info "HTTP $(http_code "$p")  http://127.0.0.1:$p"
      return 0
    fi
    sleep 1; i=$((i+1))
    [ $((i % 10)) -eq 0 ] && info "等待端口 $p … ${i}s/${t}s"
  done
  err "端口 $p 在 ${t}s 内未就绪，请查看日志: $LOGS/${KEY}.log"
  return 1
}

kill_port() {  # kill_port <port> <名称>
  local p="$1" name="${2:-$1}" pid i=0
  pid="$(port_pid "$p")"
  if [ -z "$pid" ]; then
    info "端口 $p（$name）未在运行"
    return 0
  fi
  info "结束 $name（PID $pid）…"
  taskkill /F /T /PID "$pid" 2>&1 | tr -d '\r' | sed 's/^/    /'
  while [ "$i" -lt 12 ]; do
    if ! port_up "$p"; then ok "已停止 $name（端口 $p 已释放）"; rm -f "$PIDS/$name.pid"; return 0; fi
    sleep 1; i=$((i+1))
  done
  err "端口 $p 仍在监听，请手动结束 PID $pid"
  return 1
}

kill_pidfile() {
  local f="$PIDS/$1.pid"
  [ -f "$f" ] || return 0
  local pid; pid="$(cat "$f" 2>/dev/null)"
  [ -n "${pid:-}" ] && taskkill /F /T /PID "$pid" >/dev/null 2>&1
  rm -f "$f"
}

ensure_redis() {
  if port_up 6379; then
    ok "Redis 6379 已在运行"
    return 0
  fi
  info "Redis 未启动，正在拉起 …"
  nohup "$REDIS_SRV" --port 6379 > "$LOGS/_redis.log" 2>&1 &
  sleep 2
  if port_up 6379; then ok "Redis 6379 已启动"; else warn "Redis 启动失败，依赖它的项目会报错"; fi
}

ensure_mysql() {
  if port_up 3306; then
    ok "MySQL 3306 已在运行"
  else
    warn "MySQL 3306 未运行 —— xxl-job 需要它。请先启动 MySQL 服务（本机路径 D:\\code\\environment\\mysql）"
  fi
}

# 后台启动：bg <key> <工作目录> <命令…>
bg() {
  local key="$1" dir="$2"; shift 2
  ( cd "$dir" && nohup "$@" >> "$LOGS/$key.log" 2>&1 < /dev/null & echo $! > "$PIDS/$key.pid" )
}

banner() {
  echo
  echo "============================================================"
  echo "  $1"
  echo "  时间 $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================================"
}

# 一次性 CLI 任务：跑完把关键输出打出来
run_once() {
  local key="$1" dir="$2" desc="$3"; shift 3
  banner "$desc"
  : > "$LOGS/$key.log"
  ( cd "$dir" && "$@" >> "$LOGS/$key.log" 2>&1 )
  local rc=$?
  echo "---- 输出（最后 25 行，完整日志 $LOGS/$key.log）----"
  tail -25 "$LOGS/$key.log"
  echo "-----------------------------------------------------------"
  if [ $rc -eq 0 ]; then ok "$desc 执行完成（exit=0）"; else err "$desc 退出码 $rc，请看上方输出"; fi
  return $rc
}

once_stop_note() {
  local key="$1"
  kill_pidfile "$key"
  info "本项目是一次性命令行 demo，跑完即退出，无需常驻关闭。"
  info "日志保留在: $LOGS/$key.log"
}

# =============================================================================
# 各项目 start / stop
# =============================================================================
P_PETCLINIC="$BASE/spring-boot-api/spring-petclinic"
P_SATOKEN="$BASE/enterprise-admin/Sa-Token/sa-token-demo"
P_XXL="$BASE/data-middleware/xxl-job"
P_NETTY="$BASE/microservices/netty"
P_HUTOOL="$BASE/java-tooling/hutool"
P_PICO="$BASE/java-tooling/picocli"
P_DP="$BASE/java-tooling/java-design-patterns"
P_EXCEL="$BASE/java-tooling/easyexcel"
P_BATCH="$BASE/integration-etl/spring-batch"
P_REDISSON="$BASE/data-middleware/redisson"

start_petclinic() {
  banner "spring-petclinic 宠物诊所（端口 8081）"
  if port_up 8081; then warn "8081 已在运行，跳过启动"; return 0; fi
  local jar="$P_PETCLINIC/target/spring-petclinic-4.0.0-SNAPSHOT.jar"
  if [ ! -f "$jar" ]; then
    info "未找到 jar，先用 Maven 打包（首次约 1 分钟）…"
    ( cd "$P_PETCLINIC" && JAVA_HOME="$JDK21" "$MVN" -B -q package -DskipTests >> "$LOGS/petclinic.log" 2>&1 )
  fi
  bg petclinic "$P_PETCLINIC" "$JAVA" -Dfile.encoding=UTF-8 -jar "$jar" --server.port=8081
  wait_port 8081 90 http
  info "打开 http://127.0.0.1:8081"
}
stop_petclinic() { banner "停止 spring-petclinic"; kill_port 8081 "petclinic"; kill_pidfile petclinic; }

start_satoken() {
  banner "Sa-Token 三服务：demo 8082 / SSO server 9000 / SSO client 9003"
  ensure_redis
  if ! port_up 8082; then
    info "启动 sa-token-demo-springboot（8082，JDK17）…"
    bg satoken "$P_SATOKEN/sa-token-demo-springboot" env JAVA_HOME="$JDK17" "$MVN" -B spring-boot:run -Dspring-boot.run.arguments=--server.port=8082
    wait_port 8082 120 http
  else warn "8082 已在运行"; fi
  if ! port_up 9000; then
    info "启动 SSO server（9000）…"
    bg sso-server "$P_SATOKEN/sa-token-demo-sso/sa-token-demo-sso-server" env JAVA_HOME="$JDK17" "$MVN" -B spring-boot:run -Dspring-boot.run.arguments=--server.port=9000
    wait_port 9000 120 http
  else warn "9000 已在运行"; fi
  if ! port_up 9003; then
    info "启动 SSO client（9003）…"
    bg sso-client "$P_SATOKEN/sa-token-demo-sso/sa-token-demo-sso3-client" env JAVA_HOME="$JDK17" "$MVN" -B spring-boot:run \
       -Dspring-boot.run.arguments="--server.port=9003 --sa-token.sso.server-url=http://127.0.0.1:9000"
    wait_port 9003 120 http
  else warn "9003 已在运行"; fi
  info "demo http://127.0.0.1:8082（zhang/123456）  认证中心 http://127.0.0.1:9000/sso/auth  client http://127.0.0.1:9003"
}
stop_satoken() {
  banner "停止 Sa-Token 三服务"
  kill_port 8082 "Sa-Token demo"
  kill_port 9000 "SSO server"
  kill_port 9003 "SSO client"
  kill_pidfile satoken; kill_pidfile sso-server; kill_pidfile sso-client
}

start_xxl() {
  banner "XXL-JOB 调度中心（端口 8080，依赖 MySQL 3306）"
  if port_up 8080; then warn "8080 已在运行，跳过启动"; return 0; fi
  ensure_mysql
  local jar="$P_XXL/xxl-job-admin/target/xxl-job-admin-3.5.1-SNAPSHOT.jar"
  if [ ! -f "$jar" ]; then
    info "未找到 jar，先用 Maven 打包 …"
    ( cd "$P_XXL" && JAVA_HOME="$JDK21" "$MVN" -B -q -pl xxl-job-admin -am package -DskipTests >> "$LOGS/xxl-job.log" 2>&1 )
  fi
  bg xxl-job "$P_XXL" "$JAVA" -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -jar "$jar" \
     --server.port=8080 --spring.datasource.password=root
  wait_port 8080 90 http
  info "打开 http://127.0.0.1:8080/auth/login （admin / 123456）"
}
stop_xxl() { banner "停止 XXL-JOB"; kill_port 8080 "xxl-job-admin"; kill_pidfile xxl-job; }

start_netty() {
  banner "Netty 4.2 Echo 服务（端口 9080）"
  if port_up 9080; then warn "9080 已在运行，跳过启动"; return 0; fi
  local V=4.2.6.Final
  local NCP="$LIBS/netty-common-$V.jar;$LIBS/netty-buffer-$V.jar;$LIBS/netty-resolver-$V.jar;$LIBS/netty-transport-$V.jar;$LIBS/netty-codec-base-$V.jar;$LIBS/netty-codec-compression-$V.jar;$LIBS/netty-handler-$V.jar"
  local SRC="$DEMOS/netty-src"
  if [ ! -d "$DEMOS/classes-netty" ]; then
    info "编译 echo 示例 …"
    "$JAVAC" -encoding UTF-8 -cp "$NCP" -d "$DEMOS/classes-netty" "$SRC"/*.java >> "$LOGS/netty.log" 2>&1
  fi
  # 端口来自 -Dport（源码默认 8007，必须显式传，否则只认 8007）
  bg netty "$DEMOS" "$JAVA" -Dfile.encoding=UTF-8 -Dport=9080 -cp "$DEMOS/classes-netty;$NCP" io.netty.example.echo.EchoServer
  wait_port 9080 30 port || return 1
  info "自测客户端（发一条消息看回显）…"
  "$JAVA" -Dfile.encoding=UTF-8 -Dport=9080 -cp "$DEMOS/classes-netty;$NCP" io.netty.example.echo.EchoClient >> "$LOGS/netty.log" 2>&1 &
  info "日志: $LOGS/netty.log（出现 READ 即收发成功）"
}
stop_netty() { banner "停止 Netty Echo"; kill_port 9080 "netty-echo"; kill_pidfile netty; }

start_hutool() {
  run_once hutool "$DEMOS" "Hutool 5.8.32 工具集 demo" \
    bash -c "\"$JAVAC\" -encoding UTF-8 -cp \"$LIBS/hutool-all-5.8.32.jar\" -d classes-ht HutoolDemo.java && \"$JAVA\" -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -cp \"classes-ht;$LIBS/hutool-all-5.8.32.jar\" HutoolDemo"
}
start_picocli() {
  local PICO="$P_PICO/picocli-examples/src/main/java/picocli/examples"
  run_once picocli "$DEMOS" "picocli 4.7.6 命令行框架 demo" \
    bash -c "\"$JAVAC\" -encoding UTF-8 -cp \"$LIBS/picocli-4.7.6.jar\" -d classes-pico \"$PICO/Greet.java\" && \"$JAVA\" -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -cp \"classes-pico;$LIBS/picocli-4.7.6.jar\" picocli.examples.Greet -u=WorkBuddy && \"$JAVA\" -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -cp \"classes-pico;$LIBS/picocli-4.7.6.jar\" picocli.examples.Greet --help"
}
start_dp() {
  run_once design-patterns "$P_DP" "java-design-patterns · strategy 模式（3 种策略切换）" \
    env JAVA_HOME="$JDK21" "$MVN" -B -q -pl strategy org.codehaus.mojo:exec-maven-plugin:3.1.0:java -Dexec.mainClass=com.iluwatar.strategy.App
}
start_excel() {
  # exec:java 与 Maven 同 JVM，用 MAVEN_OPTS 指定输出编码，避免 GBK 乱码
  run_once easyexcel "$DEMOS/easyexcel-demo" "easyexcel 4.0.3 · 2 万行写读 benchmark" \
    env JAVA_HOME="$JDK21" MAVEN_OPTS="-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8" \
    "$MVN" -B -q org.codehaus.mojo:exec-maven-plugin:3.1.0:java -Dexec.mainClass=ExcelDemo
}
start_batch() {
  if [ ! -f "$DEMOS/spring-batch-demo/target/spring-batch-demo-1.0.jar" ]; then
    info "首次运行，先打包 demo …"
    ( cd "$DEMOS/spring-batch-demo" && JAVA_HOME="$JDK21" "$MVN" -B -q package -DskipTests >> "$LOGS/spring-batch.log" 2>&1 )
  fi
  run_once spring-batch "$DEMOS/spring-batch-demo" "Spring Batch 批处理 demo（CSV 读→加工→写，含 skip 容错）" \
    "$JAVA" -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -jar target/spring-batch-demo-1.0.jar
}
start_redisson() {
  ensure_redis
  run_once redisson "$DEMOS/redisson-demo" "Redisson 3.35 分布式对象/分布式锁 demo" \
    bash -c "CP=\"target/classes;\"\$(cat cp.txt 2>/dev/null); if [ ! -f cp.txt ]; then JAVA_HOME=\"$JDK21\" \"$MVN\" -B -q compile dependency:build-classpath -Dmdep.outputFile=cp.txt; CP=\"target/classes;\"\$(cat cp.txt); fi; \"$JAVA\" -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -cp \"\$CP\" RedissonDemo"
}

# =============================================================================
# 分发
# =============================================================================
KEY="${1:-}"; ACTION="${2:-start}"

case "$KEY" in
  petclinic)        S=start_petclinic;       T=stop_petclinic ;;
  satoken)          S=start_satoken;         T=stop_satoken ;;
  xxl-job)          S=start_xxl;             T=stop_xxl ;;
  netty)            S=start_netty;           T=stop_netty ;;
  hutool)           S=start_hutool;          T=once_stop_note ;;
  picocli)          S=start_picocli;         T=once_stop_note ;;
  design-patterns)  S=start_dp;              T=once_stop_note ;;
  easyexcel)        S=start_excel;           T=once_stop_note ;;
  spring-batch)     S=start_batch;           T=once_stop_note ;;
  redisson)         S=start_redisson;        T=once_stop_note ;;
  *) echo "未知项目 key: ${KEY:-空}"; echo "可用: petclinic satoken xxl-job netty hutool picocli design-patterns easyexcel spring-batch redisson"; exit 2 ;;
esac

case "$ACTION" in
  start)   $S ;;
  stop)    $T ;;
  restart) $T; sleep 1; $S ;;
  status)
    banner "状态：$KEY"
    for p in 8080 8081 8082 9000 9003 9080 6379 3306; do
      if port_up $p; then ok "端口 $p 监听中（PID $(port_pid $p)）"; fi
    done ;;
  *) echo "用法: run.sh <项目key> start|stop|restart|status"; exit 2 ;;
esac
