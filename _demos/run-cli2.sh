#!/bin/bash
# 修好后的 picocli + netty 4.2 echo
set -u
BASE="D:/code/workbuddy/workbuddy-project/java"
LIB="$BASE/_libs"; OUT="$BASE/_demos"
JDK="D:/code/environment/jdk21/jdk-21.0.12.1+1/bin/java.exe"
JAVAC="D:/code/environment/jdk21/jdk-21.0.12.1+1/bin/javac.exe"
export MSYS2_ARG_CONV_EXCL='*'
L="$OUT/run-cli2.log"; : > "$L"

echo "########## picocli Greet（正确参数） ##########" >> "$L"
"$JDK" -Dfile.encoding=UTF-8 -cp "$OUT/classes-pico;$LIB/picocli-4.7.6.jar" picocli.examples.Greet -u=WorkBuddy >> "$L" 2>&1
"$JDK" -Dfile.encoding=UTF-8 -cp "$OUT/classes-pico;$LIB/picocli-4.7.6.jar" picocli.examples.Greet --help >> "$L" 2>&1

echo "########## netty 4.2 echo server/client ##########" >> "$L"
V=4.2.6.Final
NCP="$LIB/netty-common-$V.jar;$LIB/netty-buffer-$V.jar;$LIB/netty-resolver-$V.jar;$LIB/netty-transport-$V.jar;$LIB/netty-codec-base-$V.jar;$LIB/netty-codec-compression-$V.jar;$LIB/netty-handler-$V.jar"
NEX="$BASE/microservices/netty/example/src/main/java/io/netty/example"
rm -rf "$OUT/classes-netty"
"$JAVAC" -encoding UTF-8 -cp "$NCP" -d "$OUT/classes-netty" "$NEX/util/ServerUtil.java" "$NEX/echo"/*.java >> "$L" 2>&1
echo "compile_exit=$?" >> "$L"
"$JDK" -Dfile.encoding=UTF-8 -cp "$OUT/classes-netty;$NCP" io.netty.example.echo.EchoServer 9080 >> "$L" 2>&1 &
SRV=$!
sleep 7
"$JDK" -Dfile.encoding=UTF-8 -cp "$OUT/classes-netty;$NCP" io.netty.example.echo.EchoClient 127.0.0.1 9080 >> "$L" 2>&1 &
CLI=$!
sleep 8
kill $CLI $SRV 2>/dev/null
echo "NETTY DONE" >> "$L"
