#!/bin/bash
# 预编译 3 个 Maven 项目（串行，避免本地仓库锁竞争）
BASE="D:/code/workbuddy/workbuddy-project/java"
MVN="D:/code/environment/apache-maven-3.9.9/bin/mvn"
JDK17="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"
JDK21="D:/code/environment/jdk21/jdk-21.0.12.1+1"
LOG="$BASE/_build-all.log"
: > "$LOG"

step() {
  echo "===== $1 =====" >> "$LOG"
  shift
  "$@" >> "$LOG" 2>&1
  echo "EXIT=$?" >> "$LOG"
}

# 1) Sa-Token demo-springboot（Spring Boot 2.5 → JDK17）
cd "$BASE/enterprise-admin/Sa-Token/sa-token-demo/sa-token-demo-springboot"
step "sa-token-demo" env JAVA_HOME="$JDK17" "$MVN" -B -q -DskipTests package

# 2) easyexcel 核心（构建 core，供 demo 用）
cd "$BASE/java-tooling/easyexcel"
step "easyexcel-core" env JAVA_HOME="$JDK21" "$MVN" -B -q -DskipTests -pl easyexcel-core -am install

# 3) hutool-all（聚合包）
cd "$BASE/java-tooling/hutool"
step "hutool-all" env JAVA_HOME="$JDK21" "$MVN" -B -q -DskipTests -pl hutool-all -am package

echo "BUILD ALL DONE" >> "$LOG"
