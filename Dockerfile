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

RUN apk add --no-cache ca-certificates tzdata busybox-suid git bash curl && \
    echo "Updating CA certificates..." && \
    update-ca-certificates && \
    echo "Cloning default configuration from pmkol/easymosdns..." && \
    # 使用 git clone --depth 1 只克隆最新版本
    git clone --depth 1 --branch main https://github.com/pmkol/easymosdns.git /easymosdns && \
    # 删除 .git 目录减小镜像体积
    rm -rf /easymosdns/.git && \
    chmod +x /easymosdns/rules/update && \
    chmod +x /easymosdns/rules/update-cdn && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    # 在最后统一清理
    apk del git

# 声明配置文件卷
VOLUME /etc/mosdns

# 暴露 DNS 服务端口
EXPOSE 53/tcp
EXPOSE 53/udp

# 设置容器的入口点
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# 设置默认执行的命令，它将被传递给入口脚本
CMD ["/usr/bin/mosdns", "start", "--dir", "/etc/mosdns"]