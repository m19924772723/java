#!/bin/bash
# 四个 CLI demo 串跑：hutool / picocli / netty echo / 设计模式 builder
set -u
BASE="D:/code/workbuddy/workbuddy-project/java"
LIB="$BASE/_libs"
OUT="$BASE/_demos"
JDK="D:/code/environment/jdk21/jdk-21.0.12.1+1/bin/java.exe"
JAVAC="D:/code/environment/jdk21/jdk-21.0.12.1+1/bin/javac.exe"
export MSYS2_ARG_CONV_EXCL='*'
: > "$OUT/run-cli.log"

echo "########## 1) hutool-all 5.8.32 ##########" >> "$OUT/run-cli.log"
cd "$OUT"
"$JAVAC" -encoding UTF-8 -cp "$LIB/hutool-all-5.8.32.jar" -d classes-ht HutoolDemo.java >> run-cli.log 2>&1
"$JDK" -Dfile.encoding=UTF-8 -cp "classes-ht;$LIB/hutool-all-5.8.32.jar" HutoolDemo >> run-cli.log 2>&1
echo "EXIT=$?" >> run-cli.log

echo "########## 2) picocli Greet ##########" >> "$OUT/run-cli.log"
PICO="$BASE/java-tooling/picocli/picocli-examples/src/main/java/picocli/examples"
"$JAVAC" -encoding UTF-8 -cp "$LIB/picocli-4.7.6.jar" -d classes-pico "$PICO/Greet.java" >> run-cli.log 2>&1
"$JDK" -Dfile.encoding=UTF-8 -cp "classes-pico;$LIB/picocli-4.7.6.jar" picocli.examples.Greet -g 早上好 WorkBuddy >> run-cli.log 2>&1
"$JDK" -Dfile.encoding=UTF-8 -cp "classes-pico;$LIB/picocli-4.7.6.jar" picocli.examples.Greet --help >> run-cli.log 2>&1
echo "EXIT=$?" >> run-cli.log

echo "########## 3) netty echo ##########" >> "$OUT/run-cli.log"
NCP="$LIB/netty-common-4.1.108.Final.jar;$LIB/netty-buffer-4.1.108.Final.jar;$LIB/netty-resolver-4.1.108.Final.jar;$LIB/netty-transport-4.1.108.Final.jar;$LIB/netty-codec-4.1.108.Final.jar;$LIB/netty-handler-4.1.108.Final.jar"
NEX="$BASE/microservices/netty/example/src/main/java/io/netty/example/echo"
"$JAVAC" -encoding UTF-8 -cp "$NCP" -d classes-netty "$NEX"/*.java >> run-cli.log 2>&1
"$JDK" -Dfile.encoding=UTF-8 -cp "classes-netty;$NCP" io.netty.example.echo.EchoServer 9080 >> run-cli.log 2>&1 &
SRV=$!
sleep 6
"$JDK" -Dfile.encoding=UTF-8 -cp "classes-netty;$NCP" io.netty.example.echo.EchoClient 127.0.0.1 9080 >> run-cli.log 2>&1
sleep 2
kill $SRV 2>/dev/null
echo "EXIT=$?" >> run-cli.log
echo "CLI DONE" >> run-cli.log
