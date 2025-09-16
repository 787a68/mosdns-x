# mosdns-x 故障排除指南

## 常见问题

### 1. 挂载配置目录后出现 "Config File 'config' Not Found" 错误

**问题描述：**
```
Error: fail to load config, failed to read config: Config File "config" Not Found in "[/etc/mosdns]"
```

**原因分析：**
这是一个 Docker 卷挂载的经典问题。当你挂载 `/etc/mosdns` 目录时，Docker 会用挂载的内容完全覆盖容器内的目录，导致镜像内置的配置文件消失。

**解决方案：**

#### 方案A：使用自动初始化（推荐）
1. 创建一个空的配置目录：
   ```bash
   mkdir -p ./mosdns-config
   ```

2. 挂载这个空目录，容器会自动复制默认配置：
   ```bash
   docker run -d \
     --name mosdns-x \
     -p 53:53/udp -p 53:53/tcp \
     -v ./mosdns-config:/etc/mosdns \
     -e crontab="0 4 * * *" \
     ghcr.io/787a68/mosdns-x:latest
   ```

#### 方案B：预先准备配置文件
1. 从容器中复制默认配置：
   ```bash
   # 先运行一个临时容器
   docker run --name temp-mosdns ghcr.io/787a68/mosdns-x:latest sleep 10
   
   # 复制配置文件到宿主机
   docker cp temp-mosdns:/etc/mosdns ./mosdns-config
   
   # 删除临时容器
   docker rm temp-mosdns
   ```

2. 然后正常挂载：
   ```bash
   docker run -d \
     --name mosdns-x \
     -p 53:53/udp -p 53:53/tcp \
     -v ./mosdns-config:/etc/mosdns \
     -e crontab="0 4 * * *" \
     ghcr.io/787a68/mosdns-x:latest
   ```

#### 方案C：不挂载配置目录
如果你不需要持久化配置，可以不挂载 `/etc/mosdns`：
```bash
docker run -d \
  --name mosdns-x \
  -p 53:53/udp -p 53:53/tcp \
  -e crontab="0 4 * * *" \
  ghcr.io/787a68/mosdns-x:latest
```

### 2. 权限问题

**问题描述：**
容器启动后无法读写配置文件。

**解决方案：**
1. 检查挂载目录的权限：
   ```bash
   sudo chown -R 1000:1000 ./mosdns-config
   sudo chmod -R 755 ./mosdns-config
   ```

2. 或者在 docker run 时指定用户：
   ```bash
   docker run -d \
     --name mosdns-x \
     --user 1000:1000 \
     -p 53:53/udp -p 53:53/tcp \
     -v ./mosdns-config:/etc/mosdns \
     ghcr.io/787a68/mosdns-x:latest
   ```

### 3. 配置文件格式问题

**问题描述：**
mosdns 启动时报配置文件格式错误。

**解决方案：**
1. 检查配置文件是否为有效的 YAML 格式
2. 确认使用的是 mosdns v5 的配置格式
3. 配置文件名应该是 `config.yaml` 或 `config`

### 4. 调试步骤

1. **查看容器日志：**
   ```bash
   docker logs -f mosdns-x
   ```

2. **进入容器检查：**
   ```bash
   docker exec -it mosdns-x sh
   # 检查配置目录
   ls -la /etc/mosdns/
   # 检查配置文件内容
   cat /etc/mosdns/config.yaml
   ```

3. **测试配置文件：**
   ```bash
   docker exec -it mosdns-x /usr/bin/mosdns start --dir /etc/mosdns --dry-run
   ```

4. **检查端口占用：**
   ```bash
   # 检查 53 端口是否被其他服务占用
   sudo netstat -tulnp | grep :53
   sudo lsof -i :53
   ```

## 最佳实践

1. **使用 docker-compose**：更容易管理配置
2. **定期备份配置**：避免配置丢失
3. **监控日志**：及时发现问题
4. **测试配置**：修改配置后先测试再应用

## 获取帮助

如果以上方案都无法解决你的问题，请：

1. 收集相关信息：
   - Docker 版本：`docker --version`
   - 容器日志：`docker logs mosdns-x`
   - 系统信息：`uname -a`
   - 挂载信息：`docker inspect mosdns-x`

2. 在 GitHub 仓库创建 Issue：[https://github.com/787a68/mosdns-x/issues](https://github.com/787a68/mosdns-x/issues)

3. 提供详细的错误信息和重现步骤
