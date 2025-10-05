#!/bin/sh
# 任何命令失败时立即退出
set -e

CONFIG_DIR="/etc/mosdns"
DEFAULT_CONFIG_DIR="/opt/easymosdns"

# 检查 /etc/mosdns 目录是否为空。如果是，则从 /opt/easymosdns 复制默认配置。
# 这解决了当用户挂载一个空目录到 /etc/mosdns 时，所有预设配置丢失的问题。
# 同时，这也为解决权限问题提供了基础，因为我们可以确保目录内容存在并由容器内的进程创建。
if [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
    echo "$CONFIG_DIR is empty. Populating with default configuration from $DEFAULT_CONFIG_DIR..."
    # 使用 -rT 可以将源目录的内容直接复制到目标目录
    cp -rT "$DEFAULT_CONFIG_DIR/" "$CONFIG_DIR/"
    echo "Default configuration copied."
fi

# 确保核心的更新脚本存在且可执行。
# 如果用户挂载的配置中缺少这些脚本，则从默认备份中恢复它们。
mkdir -p "$CONFIG_DIR/rules" # 确保 rules 目录存在

for script in update update-cdn; do
    if [ ! -x "$CONFIG_DIR/rules/$script" ]; then
        echo "NOTICE: '$script' script missing or not executable. Restoring..."
        cp "$DEFAULT_CONFIG_DIR/rules/$script" "$CONFIG_DIR/rules/$script"
        chmod +x "$CONFIG_DIR/rules/$script"
    fi
done

CRONTAB_FILE="/etc/crontabs/root"

# 动态生成 crontab 配置文件
# 将日志输出重定向到容器的标准输出流，方便通过 docker logs 查看
echo "Initializing cron jobs..."
if [ -n "$crontab" ]; then
    echo "$crontab $CONFIG_DIR/rules/update >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled direct update: '$crontab'"
fi

if [ -n "$crontabcnd" ]; then
    echo "$crontabcnd $CONFIG_DIR/rules/update-cdn >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled CDN update: '$crontabcnd'"
fi

# 如果定义了任何 cron 任务，则启动 cron 守护进程
if [ -f "$CRONTAB_FILE" ] && [ -s "$CRONTAB_FILE" ]; then
    echo "Starting cron daemon..."
    crond -b -l 8
else
    echo "No cron jobs defined."
fi

echo "Starting mosdns service..."
# 执行 CMD 传入的命令，即启动 mosdns
exec "$@"