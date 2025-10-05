#!/bin/sh
# 任何命令失败时立即退出
set -e

CONFIG_DIR="/etc/mosdns"
DEFAULT_CONFIG_DIR="/easymosdns"

# 检查 /etc/mosdns 目录是否为空。如果是，则从 /easymosdns 复制默认配置。
# 这解决了当用户挂载一个空目录到 /etc/mosdns 时，所有预设配置丢失的问题。
if [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
    echo "$CONFIG_DIR is empty. Populating with default configuration from $DEFAULT_CONFIG_DIR..."
    # 使用 -rT 可以将源目录的内容直接复制到目标目录
    cp -rT "$DEFAULT_CONFIG_DIR/" "$CONFIG_DIR/"
    echo "Default configuration copied."
fi
# 将挂载的 `/data/config.yml` 文件复制并覆盖到 /etc/mosdns
if [ -f "/data/config.yaml" ]; then
    echo "Found custom config at /data/config.yml. Copying to $CONFIG_DIR..."
    # 复制并覆盖默认配置
    cp -fv /data/config.yml "$CONFIG_DIR/"
fi

CRONTAB_FILE="/etc/crontabs/root"
# 动态生成 crontab 配置文件
# 将日志输出重定向到容器的标准输出流，方便通过 docker logs 查看
echo "Initializing cron jobs..."
if [ -n "$crontab" ]; then
    # 执行 /easymosdns/rules/中的 update 脚本
    echo "$crontab $DEFAULT_CONFIG_DIR/rules/update >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled direct update: '$crontab'. Using pristine script."
fi

if [ -n "$crontabcnd" ]; then
    # 执行 /easymosdns/rules/中的 update-cdn 脚本
    echo "$crontabcnd $DEFAULT_CONFIG_DIR/rules/update-cdn >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled CDN update: '$crontabcnd'. Using pristine script."
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