#!/bin/bash
# 今天要摸的 10 个 Java 项目：按子方向 shallow clone，直连优先、失败切机场代理
BASE="D:/code/workbuddy/workbuddy-project/java"
PROXY="http://127.0.0.1:33210"
LOG="$BASE/_clone-java.log"
: > "$LOG"

clone() {
  local repo="$1" dest="$2"
  local name=$(basename "$repo")
  rm -rf "$BASE/$dest/$name"
  mkdir -p "$BASE/$dest"
  echo "=== $repo -> $dest" >> "$LOG"
  if git clone --depth 1 --quiet "https://github.com/$repo.git" "$BASE/$dest/$name" >>"$LOG" 2>&1; then
    echo "OK direct: $repo" >> "$LOG"
    return 0
  fi
  echo "direct failed, retry via proxy: $repo" >> "$LOG"
  if GIT_SSL_NO_VERIFY=1 git -c http.proxy=$PROXY -c https.proxy=$PROXY clone --depth 1 --quiet "https://github.com/$repo.git" "$BASE/$dest/$name" >>"$LOG" 2>&1; then
    echo "OK proxy: $repo" >> "$LOG"
    return 0
  fi
  echo "FAIL: $repo" >> "$LOG"
  return 1
}

clone spring-projects/spring-petclinic   spring-boot-api
clone dromara/Sa-Token                   enterprise-admin
clone alibaba/easyexcel                  java-tooling
clone iluwatar/java-design-patterns      java-tooling
clone remkop/picocli                     java-tooling
clone netty/netty                        microservices
clone spring-projects/spring-batch       integration-etl
clone redisson/redisson                  data-middleware
clone xuxueli/xxl-job                    data-middleware
clone dromara/hutool                     java-tooling

echo "ALL DONE" >> "$LOG"
