#!/bin/bash

# 指定要监视的进程名称
process_names=("yunshu-daemon" "yunshu-updater" "yunshu-cross" "screenshot_serv")

# 获取当前时间戳
start_time=$(date +%s)

# 当$1为空或非数字时，设置默认统计时间为180s
if [[ -z "$1" || ! "$1" =~ ^[0-9]+$ ]]; then
    interval=180
else
    interval="$1"
fi

# 计算一小时后的时间戳
end_time=$((start_time + $interval))

# 创建数据文件保存内存占用数据
output_file="memory_usage.dat"

# 打印表头到输出文件
echo "Time ${process_names[@]/%/ MB}" | tr ' ' '\t' > "$output_file"

# 初始化累加内存占用量和样本数
declare -A total_rss
declare -A sample_count

# 设置初始值
for process_name in "${process_names[@]}"; do
    total_rss["$process_name"]=0
    sample_count["$process_name"]=0
done

# 每隔一段时间获取一次内存占用情况并记录到文件
while [ "$(date +%s)" -lt "$end_time" ]; do
    current_time=$(date +"%H:%M:%S")
    # 用于存储当前时间戳下的内存使用情况
    rss_list=()
    for process_name in "${process_names[@]}"; do
	pids=$(pgrep "$process_name")
        if [[ $process_name == "yunshu-cross" ]]; then
            rss_usage=0
            # 计算pid总数量
	    pid_count=$(echo "$pids" | wc -w)
	    #echo "pids: $pids pid_count: $pid_count"
            # 将pids转化为以逗号分割
            pids=$(echo "$pids" | tr '\n' ',')
	    # 设置awk输出值为数组
            mapfile -t mems < <(pidstat -r -p "$pids" 1 1 | tail -n $pid_count | awk '{print $7}')
	    for rss in "${mems[@]}"; do
                if ! grep -qE '^[0-9]+(\.[0-9]+)?$' <<< "$rss"; then
                    rss=0
                fi
		#echo "------rss: $rss------"
                rss_usage=$(echo "$rss_usage + $rss" | bc -l)
            done
        else
            # 获取进程内存占用信息（以KB为单位）
            rss_usage="$(pidstat -r -p "$pids" 1 1 | tail -n 1 | awk '{print $7}')"
        fi
	rss_mb=$((rss_usage / 1024))
        # 记录内存使用量
	echo "----------$process_name: $rss_mb----------"
	rss_list+=("$rss_mb")
        # 更新累加内存占用量和样本数
        total_rss["$process_name"]=$((total_rss["$process_name"] + rss_mb))
        sample_count["$process_name"]=$((sample_count["$process_name"] + 1))
    done
    echo "----------开始写入文件----------"
    # 将时间戳和每个进程的内存使用量写入到文件
    echo -e "$current_time\t${rss_list[@]}" | tr ' ' '\t' >> "$output_file"
    # 等待一段时间
    #sleep 1
done

# 打印平均内存使用情况
echo "Memory usage data saved to $output_file"
echo "Average memory usage:"

for process_name in "${process_names[@]}"; do
    average_rss=$((total_rss["$process_name"] / sample_count["$process_name"]))
    echo "Process $process_name: $average_rss MB"
done

# 使用gnuplot绘制图表
gnuplot << EOF
    set terminal png
    set output 'memory_usage.png'
    set title 'Memory Usage for Processes'
    set xlabel 'Time'
    set ylabel 'RSS (MB)'
    set xdata time
    set timefmt '%H:%M:%S'
    set format x "%H:%M:%S"
    set grid
    set xtics 60
    set xtics rotate by 45 right
    
    # 绘制内存占用曲线
    plot "$output_file" using 1:2 with linespoints title "${process_names[0]}" linecolor rgb "red", \
         "" using 1:3 with linespoints title "${process_names[1]}", \
    	 "" using 1:4 with linespoints title "${process_names[2]}", \
    	 "" using 1:5 with linespoints title "${process_names[3]}"
EOF
