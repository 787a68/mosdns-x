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
    echo "Updating CA certificates..." && \
    update-ca-certificates && \
    echo "Downloading default configuration from pmkol/easymosdns..." && \
    # 创建目标目录
    mkdir -p /easymosdns && \
    # 1. 下载 main 分支的 zip 包
    curl -sSL "https://github.com/pmkol/easymosdns/archive/refs/heads/main.zip" -o /tmp/easymosdns.zip && \
    # 2. 使用 --strip-components=1 直接解压到目标目录，无需再 mv
    unzip -q /tmp/easymosdns.zip -d /easymosdns --strip-components=1 && \
    # 清理下载的临时文件
    rm /tmp/easymosdns.zip && \
    # 确保更新脚本和入口脚本有可执行权限
    chmod +x /easymosdns/rules/update && \
    chmod +x /easymosdns/rules/update-cdn && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    # 清理不再需要的包
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