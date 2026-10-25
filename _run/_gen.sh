#!/usr/bin/env bash
# 一次性生成器：给每个项目目录写入 start.cmd / stop.cmd / start.sh / stop.sh
set -eu
BASE="D:/code/workbuddy/workbuddy-project/java"

pairs="
spring-boot-api/spring-petclinic|petclinic|spring-petclinic 宠物诊所  端口 8081
enterprise-admin/Sa-Token|satoken|Sa-Token 鉴权+SSO  端口 8082/9000/9003
data-middleware/xxl-job|xxl-job|XXL-JOB 调度中心  端口 8080 (需 MySQL)
microservices/netty|netty|Netty Echo 服务  端口 9080
java-tooling/hutool|hutool|Hutool 工具集 demo  命令行
java-tooling/picocli|picocli|picocli 命令行框架 demo  命令行
java-tooling/java-design-patterns|design-patterns|设计模式 strategy 演示  命令行
java-tooling/easyexcel|easyexcel|EasyExcel 读写 benchmark  命令行
integration-etl/spring-batch|spring-batch|Spring Batch 批处理 demo  命令行
data-middleware/redisson|redisson|Redisson 分布式锁 demo  命令行 (需 Redis)
"

# ---- .cmd 模板（纯 ASCII，避免 cmd 编码问题）----
mk_cmd() { # mk_cmd <action> <key> <desc>
  cat <<EOF
@echo off
chcp 65001 >nul
setlocal
rem $3
set "BASH=D:\\code\\environment\\Git\\bin\\bash.exe"
if not exist "%BASH%" set "BASH=C:\\Program Files\\Git\\bin\\bash.exe"
if not exist "%BASH%" (
  echo [X] bash.exe not found. Please install Git for Windows.
  pause
  exit /b 1
)
"%BASH%" "%~dp0../../_run/run.sh" $2 $1
echo %cmdcmdline% | findstr /i /c:"%~nx0" >nul && pause
endlocal
EOF
}

mk_sh() { # mk_sh <action> <key> <desc>
  cat <<EOF
#!/usr/bin/env bash
# $3
exec bash "\$(cd "\$(dirname "\$0")/../.." && pwd)/_run/run.sh" $2 $1
EOF
}

echo "$pairs" | while IFS='|' read -r rel key desc; do
  [ -z "$rel" ] && continue
  d="$BASE/$rel"
  mk_cmd start "$key" "$desc" > "$d/start.cmd"
  mk_cmd stop  "$key" "$desc" > "$d/stop.cmd"
  mk_sh  start "$key" "$desc" > "$d/start.sh"
  mk_sh  stop  "$key" "$desc" > "$d/stop.sh"
  chmod +x "$d/start.sh" "$d/stop.sh" 2>/dev/null || true
  # .cmd 转 CRLF，兼容老版本 cmd.exe
  python - "$d/start.cmd" "$d/stop.cmd" <<'PY'
import sys
for f in sys.argv[1:]:
    data = open(f, 'rb').read().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    open(f, 'wb').write(data)
PY
  echo "OK  $rel  ->  start.cmd stop.cmd start.sh stop.sh"
done

chmod +x "$BASE/_run/run.sh"
echo "全部生成完毕"
