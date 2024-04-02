#!/bin/bash

# 指定要监视的进程名称
process_name="yunmai-cross"
pids=()
# 使用pgrep命令获取具有指定名称的所有进程的PID
mpid=$(pgrep "$process_name")

pids+=$mpid


# 打印所有PID
echo "PIDs of processes with name '$process_name':"
echo "$pids"
