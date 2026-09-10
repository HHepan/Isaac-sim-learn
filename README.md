# Isaac-sim-learn
用于记录对isaac sim的学习过程与学习成果

## 1. 拉取 Docker 镜像

```bash
sudo docker pull nvcr.io/nvidia/isaac-sim:5.1.0
```

---

## 2. 构建启动脚本与配置挂载目录

本仓库根目录下创建启动脚本 `start-isaac.sh`，内容参考如下：

```bash
sudo docker run --name {容器名称} --entrypoint bash -it --gpus all -e "ACCEPT_EULA=Y" --rm --network=host --user root \
    -e HTTP_PROXY=http://127.0.0.1:7890 \
    -e HTTPS_PROXY=http://127.0.0.1:7890 \
    -e NO_PROXY=localhost,127.0.0.1,172.17.0.1 \
    -e OMNI_TLS_HTTP_PROXY=http://127.0.0.1:7890 \
    -e OMNI_TLS_HTTPS_PROXY=http://127.0.0.1:7890 \
    -v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
    -v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
    -v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
    -v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
    -v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
    -v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
    -v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
    -v ~/docker/isaac-sim/documents:/root/Documents:rw \
    -v {服务器中的挂载目录}:/workspace:rw \
    -v {本地资产目录}/Assets:/isaac_assets:ro \
    nvcr.io/nvidia/isaac-sim:5.1.0
```

> **本地资产挂载说明**：由于 NVIDIA S3 资产库在国内直连不稳定（Content 面板在线拖取报 `Usd crate bootstrap section corrupt`），推荐从官网下载离线资产包，解压后将 `Assets` 目录以只读方式挂载到容器的 `/isaac_assets`。之后在 Isaac Sim 中引用本地资产时使用路径 `/isaac_assets/Isaac/5.1/...`，例如 Go2 机器狗：`/isaac_assets/Isaac/5.1/Isaac/Robots/Unitree/Go2/go2.usd`。
>
> 已下载并解压的官方资产包（位于 `/home/lijiahao/datasets/isaac-sim-assets/`）：
>
> | 资产包 | 大小 | 内容 |
> |---|---|---|
> | `robots_and_sensors` | 2.8 GB | 机器人（Go2 等四足/机械臂）+ 传感器 |
> | `materials_and_props` | 3.7 GB | 材质库 + 道具 |
> | `environments` | 14.5 GB | 环境场景（仓库/医院/办公室/户外等） |

### 2.1 资产包下载地址（官方）

| 资产包 | 下载链接 | 大小 |
|---|---|---|
| `robots_and_sensors` | `https://downloads.isaacsim.nvidia.com/isaac-sim-assets-robots_and_sensors-5.1.0.zip` | 2.8 GB |
| `materials_and_props` | `https://downloads.isaacsim.nvidia.com/isaac-sim-assets-materials_and_props-5.1.0.zip` | 3.7 GB |
| `environments` | `https://downloads.isaacsim.nvidia.com/isaac-sim-assets-environments-5.1.0.zip` | 14.5 GB |

### 2.2 下载方式（走代理 + 断点续传）

由于国内直连 NVIDIA CDN 不稳定，推荐走宿主机 Clash 代理（端口 `7890`），并用 `wget -c` 断点续传：

```bash
# 以 environments 为例（其他两个把文件名替换即可）
mkdir -p /home/lijiahao/datasets/isaac-sim-assets
cd /home/lijiahao/datasets/isaac-sim-assets

# 前台下载（可 Ctrl+C 中断，之后用同样的命令续传）
wget -c --proxy=on -e "https_proxy=http://127.0.0.1:7890" \
    "https://downloads.isaacsim.nvidia.com/isaac-sim-assets-environments-5.1.0.zip" \
    -O isaac-sim-assets-environments-5.1.0.zip

# 或后台下载（setsid 脱离终端，关掉 SSH 也不中断）
setsid nohup wget -c --proxy=on -e "https_proxy=http://127.0.0.1:7890" \
    "https://downloads.isaacsim.nvidia.com/isaac-sim-assets-environments-5.1.0.zip" \
    -O isaac-sim-assets-environments-5.1.0.zip </dev/null > download.log 2>&1 & disown
```

下载完成后解压（解压目标需与 `start-isaac.sh` 中的挂载路径一致）：

```bash
cd /home/lijiahao/datasets/isaac-sim-assets
unzip -q -o isaac-sim-assets-environments-5.1.0.zip -d extracted/
```

解压后的目录结构：`extracted/Assets/Isaac/5.1/Isaac/{Robots,Sensors,Environments,Materials,Props}/`。

> **注意**：`wget -c` 断点续传依赖服务器支持 `Range` 请求（NVIDIA CDN 支持 ✓）。下载中断后直接重跑同一条命令即可从断点继续，无需重下。若用后台方式，切记用 `setsid` 脱离进程组，否则终端断开时下载进程会被连坐杀掉。

> 说明：第 10 行 `-v` 之前的若干行用于缓存/日志等目录的挂载，避免每次启动容器都重新下载/初始化；**一般无需改动**，保持默认即可。

> ⚠️ **网络代理配置（重要）**：`HTTP_PROXY` / `HTTPS_PROXY` 这几行是给容器内程序（apt、pip、Isaac Sim Content 面板拉资产）走宿主机 Clash 代理用的。NVIDIA S3 在国内直连极不稳定，会导致 `Usd crate bootstrap section corrupt` 报错（流式下载中断导致 USD crate 残缺）。  
> 
> 三点必须确认：
> 1. 宿主机 Clash（或其他代理）的 HTTP 端口为 `7890`，且监听 `0.0.0.0` 而非仅 `127.0.0.1`（Clash 默认 `*:7890` ✓）。如果你的代理端口不同，把脚本里的 `7890` 全部替换掉。
> 2. `OMNI_TLS_HTTP_PROXY` / `OMNI_TLS_HTTPS_PROXY` 这两行**不能省**——Isaac Sim 的 HTTP 客户端默认不读标准 `HTTP_PROXY` 环境变量，必须显式声明。
> 3. Clash 规则需要放行 `*.amazonaws.com`（让 S3 走代理节点）。可以在 Clash Dashboard → Rules 里搜 `amazonaws` 确认。

随后，编辑 `Isaac-sim-learn/start_issac.sh` 文件，修改第 10 行：

```bash
-v {服务器中的挂载目录}:/workspace:rw \
```

将 `{服务器中的挂载目录}` 替换为你的实际路径，建议直接使用该项目的路径。

---

## 3. 进入 Isaac Sim 容器

首次使用前需要为启动脚本赋予执行权限：

```bash
chmod +x start-isaac.sh
```

随后执行：

```bash
cd Isaac-sim-learn
./start-isaac.sh
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

---

## 9. 在 Docker 容器中安装 Isaac Lab（完整指南 + 踩坑记录）

> 本章基于 Isaac Sim 5.1.0 Docker 容器 + Isaac Lab v2.3.0 实战踩坑整理，全部经过验证（2026-09）。

### 9.1 版本对应关系（最重要）

**Isaac Lab 必须选与容器内 Isaac Sim 版本配套的 release tag，而不是拉最新代码。**

| Isaac Sim | Isaac Lab | 容器内 Python |
|---|---|---|
| 5.1.0 | **v2.3.x** | 3.11.13 |
| 5.0 | v2.2.x | 3.11 |
| 4.5 | v2.0/2.1 | 3.10/3.11 |

> ⚠️ 若 clone 了 `main` 分支，`./isaaclab.sh --install` 会报 `Package 'isaaclab' requires a different Python: 3.11.13 not in '>=3.12'`。因为 main 分支已转向 Python ≥ 3.12，而容器内是 3.11。**必须 checkout 对应 tag**。

### 9.2 安装步骤

```bash
# 1. 克隆 Isaac Lab（在挂载目录 /workspace 下）
cd /workspace
git clone https://github.com/isaac-sim/IsaacLab.git
cd IsaacLab

# 2. 切换到与 Isaac Sim 5.1 匹配的版本
git fetch --tags
git tag | sort -V | tail -10   # 查看可用版本
git checkout v2.3.0

# 3. 安装系统依赖
apt update && apt install -y git

# 4. 创建 python wrapper（容器内没有裸 python3，这是关键）
#    Isaac Sim 的 Python 封装在 /isaac-sim/python.sh，需要暴露为 python3 / python
cat > /usr/local/bin/python3 <<'EOF'
#!/bin/bash
exec /isaac-sim/python.sh "$@"
EOF
chmod +x /usr/local/bin/python3
ln -sf /usr/local/bin/python3 /usr/local/bin/python   # 部分脚本调用 python 而非 python3

# 5. 建立 _isaac_sim 目录链接（v2.3.0 的 isaaclab.sh 期望这个布局）
ln -sf /isaac-sim /workspace/IsaacLab/_isaac_sim

# 6. 降级 setuptools 并安装 flatdict（绕过构建隔离的坑）
python3 -m pip install --upgrade "setuptools<81" wheel
python3 -m pip install --no-build-isolation flatdict==4.0.1

# 7. 安装 isaaclab 核心包与任务包（必须 --no-build-isolation）
cd /workspace/IsaacLab
python3 -m pip install --no-build-isolation -e source/isaaclab
python3 -m pip install --no-build-isolation -e source/isaaclab_tasks

# 8. 安装 RL 框架
python3 -m pip install skrl==2.1.0     # skrl（推荐，Anymal/Go2/Ant 都支持）
# 或 RSL-RL：python3 -m pip install rsl-rl-lib

# 9. 验证安装（用完整脚本，不要裸 import！）
python3 scripts/tutorials/00_sim/create_empty.py --headless
# 看到 "[INFO]: Setup complete..." 即安装成功
```

> **验证方式的坑**：不要用 `python3 -c "import isaaclab"` 验证！Isaac Lab 的模块（如 `omni.physics`）要等 `SimulationApp` 启动后才由 Kit 运行时动态加载，裸 import 必然报 `ModuleNotFoundError: No module named 'omni.physics'`——这是正常现象，不是安装失败。**正确验证方式是跑一个完整脚本**（脚本内部先启动 SimulationApp）。

### 9.3 训练命令

```bash
cd /workspace/IsaacLab

# skrl 框架训练（--max_iterations 真正控制训练量）
python3 scripts/reinforcement_learning/skrl/train.py \
    --task=Isaac-Velocity-Flat-Unitree-Go2-v0 --headless \
    --max_iterations 3000     # 3000 迭代 × 24 rollouts = 72000 timesteps

# 导出 15 秒评估视频（--video_length 750 ≈ 50fps × 15s）
python3 scripts/reinforcement_learning/skrl/play.py \
    --task=Isaac-Velocity-Flat-Unitree-Go2-v0 --headless \
    --video --video_length 750
```

> **训练量参数的坑**：yaml 里的 `trainer.timesteps` 默认值很小（Ant=8000、Go2=7200），这只是"热身量"。`--max_iterations N` 会把它换算为 `N × rollouts`。想真正加大训练量必须显式传 `--max_iterations`（如 3000），否则默认只训几分钟。

### 9.4 资产路径问题（Anymal/Go2 等常见坑）

Isaac Lab 的机器人资产默认引用 **NVIDIA 云端 Nucleus**（如 `ISAACLAB_NUCLEUS_DIR`），容器内无外网时加载失败，症状为：

- `ValueError: No contact sensors added to the prim: '/World/envs/env_0/Robot'`（USD 没加载成功，Robot prim 是空的）
- 或 `RuntimeError: PytorchStreamReader failed reading zip archive`（执行器网络 .pt 下载损坏）

**解决**：把配置里的 `usd_path` / `network_file` 改成本地路径。

```bash
# 本地资产在 /isaac_assets（挂载的离线资产包），例如：
#   Go2:  /isaac_assets/Isaac/5.1/Isaac/Robots/Unitree/Go2/go2.usd
#   Anymal-C: /isaac_assets/Isaac/5.1/Isaac/Robots/ANYbotics/anymal_c/anymal_c.usd

# 修改 isaaclab_assets/robots/unitree.py 与 anymal.py 的 usd_path
sed -i 's|usd_path=f"{ISAACLAB_NUCLEUS_DIR}/Robots/Unitree/Go2/go2.usd",|usd_path="/isaac_assets/Isaac/5.1/Isaac/Robots/Unitree/Go2/go2.usd",|' \
    /workspace/IsaacLab/source/isaaclab_assets/isaaclab_assets/robots/unitree.py
```

**Anymal-C 额外需要执行器网络文件**（LSTM 电机模型）：

- 默认引用云端 `ISAACLAB_NUCLEUS_DIR/ActuatorNets/ANYbotics/anydrive_3_lstm_jit.pt`
- 需下载到挂载目录（宿主机有外网时）：正确 URL 为
  `https://omniverse-content-production.s3-us-west-2.amazonaws.com/Assets/Isaac/4.5/Isaac/IsaacLab/ActuatorNets/ANYbotics/anydrive_3_lstm_jit.pt`
  （注意路径有**两层 `Isaac`**：`/Assets/Isaac/4.5/Isaac/IsaacLab/...`）
- 下载到 `~/MachineLr/hepan/Isaac-sim-learn/assets/`（容器内 `/workspace/assets/`），再改 `anymal.py` 的 `network_file` 指向它
- Go2 用 `DCMotorCfg`（普通电机），**无需**额外 .pt 文件，只改 USD 路径即可

### 9.5 skrl 2.1.0 API 断层（play.py 报错修复）

Isaac Lab 2.3.0 自带脚本用的是 skrl 1.x 的 API，与 skrl 2.1.0 不兼容。`play.py` 需改两处：

```python
# scripts/reinforcement_learning/skrl/play.py

# 第 210 行（原）：
runner.agent.set_running_mode("eval")
# 改为（skrl 2.x）：
runner.agent.enable_training_mode(False)

# 第 222 行（原）：
outputs = runner.agent.act(obs, timestep=0, timesteps=0)
# 改为（act() 签名变化，states 为必需参数传 None）：
outputs = runner.agent.act(obs, None, timestep=0, timesteps=0)
```

> 报错对应关系：`AttributeError: 'PPO' object has no attribute 'set_running_mode'` / `'eval'` → 用 `enable_training_mode(False)`；`TypeError: PPO.act() missing 1 required positional argument: 'states'` → 补 `None`。

### 9.6 无显示器（容器 headless）注意点

1. **跑任何训练/脚本一律加 `--headless`**。不加会尝试打开渲染窗口，容器内无显示器时卡死在渲染器初始化（GPU 空转、进程不退出）。
2. **导出视频**用 `--video --video_length N`，视频输出到 `logs/skrl/<task>/<run>/videos/play/`。
3. 脚本启动后会进入**无限 step 循环**（RL 训练的正常形态），用 `PYTHONUNBUFFERED=1` 重定向到文件后台跑，避免 stdout 全缓冲导致日志"卡住"假象。

### 9.7 断电/关机后恢复（容器被 --rm 删除）

`start-isaac.sh` 里带 `--rm`，断电或关机后容器会被自动删除，**容器内安装全部丢失**，但挂载卷（`/workspace`、缓存、日志）全部保留。恢复步骤：

```bash
# 1. 重启容器（./start-isaac.sh）后，重建 wrapper
cat > /usr/local/bin/python3 <<'EOF'
#!/bin/bash
exec /isaac-sim/python.sh "$@"
EOF
chmod +x /usr/local/bin/python3
ln -sf /usr/local/bin/python3 /usr/local/bin/python

# 2. 重装系统依赖与核心库
apt update && apt install -y git
python3 -m pip install --upgrade "setuptools<81" wheel
python3 -m pip install --no-build-isolation flatdict==4.0.1
python3 -m pip install --no-build-isolation -e /workspace/IsaacLab/source/isaaclab
python3 -m pip install --no-build-isolation -e /workspace/IsaacLab/source/isaaclab_tasks
python3 -m pip install skrl==2.1.0 hydra-core h5py absl-py

# 3. 修复断电损坏的 pip（vendored packaging 符号链接断裂）
#    症状：ModuleNotFoundError: No module named 'pip._vendor.packaging._structures'
python3 -m ensurepip --upgrade   # 或从 ensurepip bundled wheel 解包恢复 pip

# 4. 修复 Isaac Sim 镜像内断掉的符号链接
#    症状：FileNotFoundError: .../pip_prebundle/packaging/_structures.py
find /isaac-sim -type l ! -exec test -e {} \; -print   # 扫描断链
#    修复示例（把断链删掉，从 site-packages 复制）：
rm /isaac-sim/exts/omni.isaac.ml_archive/pip_prebundle/torch/_vendor/packaging/_structures.py
cp /isaac-sim/kit/python/lib/python3.11/site-packages/packaging/_structures.py \
   /isaac-sim/exts/omni.isaac.ml_archive/pip_prebundle/torch/_vendor/packaging/_structures.py

# 5. 重装被损坏的 tensorboard（断电后可能变成残缺的 1.10.0）
python3 -m pip install --force-reinstall --no-deps "tensorboard==2.18.0"

# 6. 验证
cd /workspace/IsaacLab
python3 scripts/tutorials/00_sim/create_empty.py --headless   # 看到 Setup complete 即恢复
```

> 💡 **预防建议**：装完环境后 `docker commit` 当前容器为镜像（如 `isaac-lab:5.1.0`），下次断电直接用它起容器，免去重装。或去掉启动脚本里的 `--rm` 标志。
