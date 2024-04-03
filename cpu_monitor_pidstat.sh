#!/bin/bash

# 指定要监视的进程名称列表
process_names=("yunshu-daemon" "yunshu-updater" "yunshu-cross" "screenshot_serv")

# 获取当前时间戳
start_time=$(date +%s)

# 设置默认统计时间为180s
if [[ -z "$1" ]]; then
    interval=180
else
    interval="$1"
fi

# 计算一小时后的时间戳
end_time=$((start_time + $interval))

# 创建数据文件保存CPU占用数据
output_file="cpu_usage.dat"

# 打印表头到输出文件
echo "Time ${process_names[@]/%/ CPU(%)}" | tr ' ' '\t' > "$output_file"

# 初始化累加CPU占用量和样本数
declare -A total_cpu
declare -A sample_count

# 设置初始值
for process_name in "${process_names[@]}"; do
    total_cpu["$process_name"]=0
    sample_count["$process_name"]=0
done

# 每隔一段时间获取一次CPU占用情况并记录到文件
while [ "$(date +%s)" -lt "$end_time" ]; do
    current_time=$(date +"%H:%M:%S")
    # 用于存储当前时间戳下的CPU占用情况
    cpu_list=()
    for process_name in "${process_names[@]}"; do
	pids=$(pgrep "$process_name")
	if [[ $process_name == "yunshu-cross" ]]; then
	    cpu_usage=0
	    # 计算pid总数量
	    pid_count=$(echo "$pids" | wc -w)
	    #echo "pids: $pids pid_count: $pid_count"
            # 将pids转化为以逗号分割
	    pids=$(echo "$pids" | tr '\n' ',')
	    mapfile -t cpus < <(pidstat -u -p "$pids" 1 1 | tail -n $pid_count | awk '{print $8}')
	    # 计算cross进程cpu总占用率
	    for cpu in "${cpus[@]}"; do
	        if ! grep -qE '^[0-9]+(\.[0-9]+)?$' <<< "$cpu"; then
       	            cpu=0
	        fi
		#echo ------cpu: $cpu------
	   	cpu_usage=$(echo "$cpu_usage + $cpu" | bc -l | awk '{printf "%.1f\n", $1}')
            done
        else	
            # 获取进程CPU占用信息
	    cpu_usage="$(pidstat -u -p "$pids" 1 1 | tail -n 1 | awk '{print $8}' || echo 0)"
	fi
        # 记录CPU占用率
	echo "----------$process_name: $cpu_usage----------"
        cpu_list+=("$cpu_usage")
        # 更新累加CPU占用量和样本数
	total_cpu["$process_name"]=$(echo "scale=1; ${total_cpu["$process_name"]} + $cpu_usage" | bc -l | awk '{printf "%.1f\n", $1}')
        sample_count["$process_name"]=$((sample_count["$process_name"] + 1))
    done
    echo "----------开始写入文件----------"
    # 将时间戳和每个进程的CPU占用率写入到文件
    echo -e "$current_time\t${cpu_list[@]}" | tr ' ' '\t' >> "$output_file"
    # 等待一段时间
    #sleep 1
done

# 打印平均CPU使用情况
echo "CPU usage data saved to $output_file"
echo "Average CPU usage:"

for process_name in "${process_names[@]}"; do
    average_cpu=$(echo "scale=1; ${total_cpu["$process_name"]} / ${sample_count["$process_name"]}" | bc -l |awk '{printf "%.1f\n", $1}')
    echo "Process $process_name: $average_cpu %"
done

# 使用gnuplot绘制图表
gnuplot <<-EOF
    set terminal png
    set output 'cpu_usage.png'
    set title 'CPU Usage for Processes'
    set xlabel 'Time'
    set ylabel 'CPU (%)'
    set xdata time
    set timefmt '%H:%M:%S'
    set format x "%H:%M:%S"
    set grid
    set xtics 60
    set xtics rotate by 45 right

    # 绘制CPU占用率曲线
    plot "$output_file" using 1:2 with linespoints title "${process_names[0]}" linecolor rgb "red", \
         "" using 1:3 with linespoints title "${process_names[1]}", \
    	 "" using 1:4 with linespoints title "${process_names[2]}", \
	 "" using 1:5 with linespoints title "${process_names[3]}"	
EOF
