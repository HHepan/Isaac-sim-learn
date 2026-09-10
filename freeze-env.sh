#!/bin/bash
# ============================================================
# 固化 Isaac Lab 容器环境为镜像（断电后免重装）
# 用法：在宿主机执行  bash freeze-env.sh
# 步骤：1. commit 当前运行容器 → 新镜像
#       2. 更新 start-isaac.sh 使用新镜像
#       3. 备份旧 start-isaac.sh
# ============================================================

set -e

# 1. 提交当前容器为镜像
echo ">>> [1/3] 提交容器 isaac-learn 为新镜像 isaac-lab:5.1.0-frozen ..."
sudo docker commit isaac-learn isaac-lab:5.1.0-frozen

# 2. 确认新镜像生成
echo ">>> 新镜像列表："
sudo docker images | grep -E "isaac-lab|isaac-sim" || true

# 3. 备份并更新启动脚本
echo ">>> [2/3] 备份原启动脚本 ..."
cp /home/lijiahao/MachineLr/hepan/Isaac-sim-learn/start-isaac.sh \
   /home/lijiahao/MachineLr/hepan/Isaac-sim-learn/start-isaac.sh.bak
echo "    备份完成：start-isaac.sh.bak"

echo ">>> [3/3] 更新 start-isaac.sh 使用固化镜像（并去掉 --rm 防删除）..."
cat > /home/lijiahao/MachineLr/hepan/Isaac-sim-learn/start-isaac.sh <<'EOF'
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
EOF
chmod +x /home/lijiahao/MachineLr/hepan/Isaac-sim-learn/start-isaac.sh

echo ""
echo "=============================================="
echo " ✅ 固化完成！"
echo " 新镜像：isaac-lab:5.1.0-frozen"
echo " 启动脚本已更新（去掉 --rm + 幂等启动，使用新镜像）"
echo " 原脚本备份：start-isaac.sh.bak"
echo ""
echo " ⚠️ 注意："
echo "  1. 当前容器 isaac-learn 还在用旧镜像运行，"
echo "     不影响，下次重启才用新镜像。"
echo "  2. 新 start-isaac.sh 已去掉 --rm 并自动清理旧容器，"
echo "     断电后直接 ./start-isaac.sh 即可，无需重装。"
echo "  3. 若想立即验证新镜像：先 exit 退出当前容器，"
echo "     再 ./start-isaac.sh。"
echo "=============================================="
