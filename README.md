# Isaac-sim-learn
用于记录对isaac sim的学习过程与学习成果

## 1. 拉取 Docker 镜像

```bash
sudo docker pull nvcr.io/nvidia/isaac-sim:5.1.0
```

---

## 2. 构建启动脚本与配置挂载目录

本仓库根目录下创建启动脚本 `start_issac.sh`，内容参考如下：

```bash
sudo docker run --name {容器名称} --entrypoint bash -it --gpus all -e "ACCEPT_EULA=Y" --rm --network=host --user root \
    -v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
    -v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
    -v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
    -v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
    -v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
    -v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
    -v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
    -v ~/docker/isaac-sim/documents:/root/Documents:rw \
    -v {服务器中的挂载目录}:/workspace:rw \
    nvcr.io/nvidia/isaac-sim:5.1.0
```

> 说明：第 10 行 `-v` 之前的若干行用于缓存/日志等目录的挂载，避免每次启动容器都重新下载/初始化；**一般无需改动**，保持默认即可。

随后，编辑 `Isaac-sim-learn/start_issac.sh` 文件，修改第 10 行：

```bash
-v {服务器中的挂载目录}:/workspace:rw \
```

将 `{服务器中的挂载目录}` 替换为你的实际路径，建议直接使用该项目的路径。

---

## 3. 进入 Isaac Sim 容器

```bash
cd Isaac-sim-learn
./start_issac.sh
```

> 进入容器后默认处于 `/isaac-sim` 目录下。

---

## 4. 启动 Isaac Sim 服务

### 4.1 安装虚拟显示器

```bash
apt-get update && apt-get install -y xvfb
```

### 4.2 启动服务

```bash
CUDA_VISIBLE_DEVICES=0 xvfb-run -a ./isaac-sim.streaming.sh --allow-root
```

> 当出现 `Isaac Sim Full Streaming App is loaded.` 日志时表示启动成功。

### 4.3 查看服务端口

```bash
sudo ss -tulpn | grep kit
```

默认端口号为 `49100`。

---

## 5. 客户端连接

1. 在本地笔记本上打开 **Isaac Sim WebRTC Streaming Client**
2. 输入服务器 IP 地址
3. 点击连接（程序默认连接端口 `49100`）

---

## 6. 安装机器学习库

在容器中执行：

```bash
./python.sh -m pip install stable-baselines3 gymnasium
```

---

## 7. 执行工作区脚本

```bash
# 切换至工作区目录
cd /workspace

# 执行脚本（场景创建或强化学习）
CUDA_VISIBLE_DEVICES=0 xvfb-run -a /isaac-sim/python.sh xxx.py
```

---

## 8. Docker 常用命令

| 命令 | 说明 |
|------|------|
| `docker images` | 查看本地所有镜像（等价于 `docker image ls`） |
| `docker ps` | 仅查看【正在运行】的容器 |
| `docker ps -a` | 查看【所有】容器（含已停止） |
| `docker ps -q` | 仅输出容器 ID（常用于脚本组合） |
| `sudo docker exec -it {容器名称} bash` | 为正在运行的容器开启新终端 |
