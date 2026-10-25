#!/bin/bash
# 剩余仓库：显式清空代理走直连（当前代理全挂，直连 200）
BASE="D:/code/workbuddy/workbuddy-project/java"

clone() {
  local repo="$1" dest="$2" name=$(basename "$1")
  local log="$BASE/_clone-$name.log"
  rm -rf "$BASE/$dest/$name"; mkdir -p "$BASE/$dest"
  : > "$log"
  env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy -u ALL_PROXY -u all_proxy \
    git -c http.proxy= -c https.proxy= -c http.lowSpeedLimit=800 -c http.lowSpeedTime=45 \
    clone --depth 1 --quiet "https://github.com/$repo.git" "$BASE/$dest/$name" >>"$log" 2>&1 \
  && echo "OK direct $repo" >> "$log" || echo "FAIL $repo" >> "$log"
}

clone alibaba/easyexcel             java-tooling      &
clone iluwatar/java-design-patterns java-tooling      &
clone dromara/hutool                java-tooling      &
wait
echo "BATCH1 DONE" >> "$BASE/_clone-batch.log"

clone redisson/redisson             data-middleware   &
clone spring-projects/spring-batch  integration-etl   &
clone xuxueli/xxl-job               data-middleware   &
wait
echo "BATCH2 DONE" >> "$BASE/_clone-batch.log"
