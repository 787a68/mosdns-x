#!/bin/sh

# 脚本执行期间，任何命令返回非零退出码时立即终止执行。
set -e

# --- 变量定义 ---
# MosDNS 配置文件存放目录
CONFIG_DIR="/etc/mosdns"
# 默认配置文件源目录
DEFAULT_CONFIG_DIR="/easymosdns"

# --- 步骤一：配置初始化 ---
# 检查目标配置目录 /etc/mosdns 是否为空。
# 如果为空，则从 /easymosdns 目录复制默认配置，并在成功后输出确认信息。
if [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
    cp -rT "$DEFAULT_CONFIG_DIR/" "$CONFIG_DIR/" && echo "检测到配置目录为空，已成功完成初始化。"
fi

# --- 步骤二：应用自定义配置 ---
# 检查 /data/config.yaml 文件是否存在。
# 如果存在，则将其复制到配置目录，用于覆盖默认设置。这通常用于通过数据卷挂载自定义配置。
if [ -f "/data/config.yaml" ]; then
    echo "应用自定义配置文件..."
    cp -fv /data/config.yaml "$CONFIG_DIR/"
fi

# --- 步骤三：日志重定向 ---
# 将 MosDNS 的日志文件路径创建一个指向标准输出的符号链接。
# 这样做可以将所有日志直接输出到容器的控制台，方便通过 `docker logs` 命令查看。
LOG_FILE_PATH="$CONFIG_DIR/mosdns.log"
echo "重定向日志到容器的标准输出..."
ln -sf /dev/stdout "$LOG_FILE_PATH"

# --- 步骤四：创建定时任务 ---
CRONTAB_FILE="/etc/crontabs/root"
# 根据环境变量 `crontab` 创建一个用于更新规则的定时任务。
# 任务的所有输出（标准输出和错误输出）都将重定向到容器主进程的标准输出流，便于统一追踪。
if [ -n "$crontab" ]; then
    echo "创建规则更新定时任务: $crontab"
    echo "$crontab $DEFAULT_CONFIG_DIR/rules/update >> /proc/1/fd/1 2>&1" > "$CRONTAB_FILE"
fi

# 根据环境变量 `crontabcnd` 创建一个用于更新 CDN 规则的定时任务。
# 注意：如果 `crontab` 和 `crontabcnd` 同时设置，此任务会覆盖上一个任务。
if [ -n "$crontabcnd" ]; then
    echo "创建 CDN 规则更新定时任务: $crontabcnd"
    echo "$crontabcnd $DEFAULT_CONFIG_DIR/rules/update-cdn >> /proc/1/fd/1 2>&1" > "$CRONTAB_FILE"
fi

# --- 步骤五：启动 Cron 守护进程 ---
# 检查定时任务配置文件是否存在且不为空。
# 如果条件满足，则在后台启动 cron 守护进程来执行已定义的任务。
if [ -f "$CRONTAB_FILE" ] && [ -s "$CRONTAB_FILE" ]; then
    echo "启动定时任务守护进程..."
    crond -b -l 8
else
    echo "未定义定时任务，跳过启动。"
fi

# --- 步骤六：启动主服务 ---
# 使用 exec 命令执行 Dockerfile 中 CMD 或在 `docker run` 时传入的命令。
# 这会将当前 shell 进程替换为 MosDNS 主程序，确保其为容器的主进程（PID 1）。
echo "启动 MosDNS 主服务..."
exec "$@"