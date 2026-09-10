#!/bin/bash
# 启动 Isaac Sim 容器（使用固化镜像 isaac-lab:5.1.0-frozen）
# 若已有同名容器存在，先停止并删除（幂等启动）

# 停止并删除旧容器（若存在）
sudo docker rm -f isaac-learn 2>/dev/null || true

# 启动新容器（去掉 --rm：断电后容器保留，免重建）
sudo docker run --name isaac-learn --entrypoint bash -it --gpus all -e "ACCEPT_EULA=Y" --network=host --user root \
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
    -v /home/lijiahao/datasets/isaac-sim-assets/extracted/Assets:/isaac_assets:ro \
    -v /home/lijiahao/MachineLr/hepan/Isaac-sim-learn:/workspace:rw \
    isaac-lab:5.1.0-frozen
