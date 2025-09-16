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

# 新增：将仓库根目录的 Cloudflare Origin CA 证书复制到镜像中
# 我们将其重命名为 .crt 后缀，这是 Alpine 系统推荐的格式
COPY origin_ca_rsa_root.pem /usr/local/share/ca-certificates/cloudflare-origin-ca-rsa.crt
COPY origin_ca_ecc_root.pem /usr/local/share/ca-certificates/cloudflare-origin-ca-ecc.crt

# 安装依赖，更新证书，克隆默认配置，授权脚本，然后清理
RUN apk add --no-cache ca-certificates tzdata git busybox-suid && \
    \
    # 更新系统证书信任列表，让刚才复制进去的证书生效
    update-ca-certificates && \
    \
    # 克隆默认配置文件到 /opt/easymosdns，以便在容器启动时按需复制
    echo "Cloning default configuration from pmkol/easymosdns to /opt/easymosdns..." && \
    git clone --depth 1 https://github.com/pmkol/easymosdns.git /opt/easymosdns && \
    # 确保更新脚本和入口脚本有可执行权限
    chmod +x /opt/easymosdns/rules/update && \
    chmod +x /opt/easymosdns/rules/update-cdn && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    # 清理不再需要的包
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