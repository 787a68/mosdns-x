# 使用 ARG 接收来自 build 命令的参数
ARG VERSION
ARG TARGETARCH

# --- 构建阶段 ---
# 此阶段负责根据架构下载对应的二进制文件
FROM alpine:latest AS builder
ARG VERSION
ARG TARGETARCH

# 安装下载和解压所需的工具
RUN apk add --no-cache curl unzip

# 下载 mosdns-x 的预编译二进制文件
RUN curl -sSL "https://github.com/pmkol/mosdns-x/releases/download/${VERSION}/mosdns-linux-${TARGETARCH}.zip" -o mosdns.zip && \
    unzip mosdns.zip mosdns && \
    chmod +x mosdns

# --- 最终镜像阶段 ---
# 这是最终发布的镜像，基于轻量的 alpine
FROM alpine:latest

# 从构建阶段复制 mosdns 可执行文件
COPY --from=builder /mosdns /usr/bin/mosdns

# 复制入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN apk add --no-cache ca-certificates tzdata busybox-suid curl unzip && \
    echo "Updating CA certificates from local files..." && \
    update-ca-certificates && \
    echo "Downloading default configuration from pmkol/easymosdns..." && \
    # 创建目标目录
    mkdir -p /easymosdns && \
    # 使用 curl 下载仓库的 zip 压缩包到 /tmp 目录
    curl -sSL "https://github.com/pmkol/easymosdns/archive/refs/heads/master.zip" -o /tmp/easymosdns.zip && \
    # 将压缩包解压到 /tmp 目录，-q 参数表示静默模式
    unzip -q /tmp/easymosdns.zip -d /tmp && \
    # 将解压出来的文件夹 (easymosdns-master) 内的所有内容移动到目标位置
    # 注意后面的 /。 表示移动文件夹内的所有内容
    mv /tmp/easymosdns-master/. /easymosdns/ && \
    # 清理下载的临时文件和解压出的空目录
    rm -rf /tmp/easymosdns.zip /tmp/easymosdns-master && \
    # 确保更新脚本和入口脚本有可执行权限
    chmod +x /easymosdns/rules/update && \
    chmod +x /easymosdns/rules/update-cdn && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    # 清理不再需要的包（用完即删）
    apk del curl unzip

# 声明配置文件卷
VOLUME /etc/mosdns

# 暴露 DNS 服务端口
EXPOSE 53/tcp
EXPOSE 53/udp

# 设置容器的入口点
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# 设置默认执行的命令，它将被传递给入口脚本
CMD ["/usr/bin/mosdns", "start", "--dir", "/etc/mosdns"]