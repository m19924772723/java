#!/bin/bash
# 剩余 8 个仓库并行拉取：直连优先（带低速超时），失败切机场代理
BASE="D:/code/workbuddy/workbuddy-project/java"
PROXY="http://127.0.0.1:33210"

clone() {
  local repo="$1" dest="$2"
  local name=$(basename "$repo")
  local log="$BASE/_clone-$name.log"
  rm -rf "$BASE/$dest/$name"; mkdir -p "$BASE/$dest"
  : > "$log"
  GIT_HTTP_LOW_SPEED_LIMIT=2000 GIT_HTTP_LOW_SPEED_TIME=25 \
    git clone --depth 1 --quiet "https://github.com/$repo.git" "$BASE/$dest/$name" >>"$log" 2>&1 \
  && { echo "OK direct $repo" >> "$log"; return 0; }
  echo "direct failed -> proxy $repo" >> "$log"
  rm -rf "$BASE/$dest/$name"
  GIT_SSL_NO_VERIFY=1 GIT_HTTP_LOW_SPEED_LIMIT=2000 GIT_HTTP_LOW_SPEED_TIME=25 \
    git -c http.proxy=$PROXY -c https.proxy=$PROXY clone --depth 1 --quiet "https://github.com/$repo.git" "$BASE/$dest/$name" >>"$log" 2>&1 \
  && { echo "OK proxy $repo" >> "$log"; return 0; }
  echo "FAIL $repo" >> "$log"
}

clone alibaba/easyexcel               java-tooling      &
clone iluwatar/java-design-patterns   java-tooling      &
clone remkop/picocli                  java-tooling      &
clone netty/netty                     microservices     &
clone spring-projects/spring-batch    integration-etl   &
clone redisson/redisson               data-middleware   &
clone xuxueli/xxl-job                 data-middleware   &
clone dromara/hutool                  java-tooling      &
wait
echo "PARALLEL DONE"
