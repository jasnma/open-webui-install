#!/bin/bash

# 检查并安装依赖的软件
REQUIRED_SOFTWARE=(nginx git python3 python3-venv python3-pip node npm)

for software in "${REQUIRED_SOFTWARE[@]}"; do
    if ! command -v "$software" &> /dev/null; then
        echo "$software 未安装，正在安装..."
        if [[ "$software" == "node" || "$software" == "npm" ]]; then
            # 使用 Homebrew 安装 Node.js 和 npm
            brew install node
        else
            # 使用 Homebrew 安装其他软件
            brew install "$software"
        fi
    else
        echo "$software 已安装"
    fi
done

# 从 GitHub 拉取最新代码
REPO_URL="https://github.com/open-webui/open-webui.git"
TARGET_DIR="open-webui"

# 如果目标目录已存在，则删除
if [ -d "$TARGET_DIR" ]; then
    echo "删除已存在的目录: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
fi

# 克隆仓库
echo "从 $REPO_URL 克隆仓库"
git clone "$REPO_URL" "$TARGET_DIR"

# 进入目标目录
cd "$TARGET_DIR" || exit

# 运行必要的设置或生成文件
echo "运行设置..."
# 在此添加您的设置命令，例如 npm install, make 等

# 生成 Open WebUI React 前端部分
echo "生成 React 前端部分..."
npm install --legacy-peer-deps
npm run build

# 备份现有的前端静态文件目录
if [ -d "/usr/share/nginx/html/open-webui" ]; then
    echo "备份现有的前端静态文件目录..."
    sudo mv /usr/share/nginx/html/open-webui /usr/share/nginx/html/open-webui.bak.$(date +%Y%m%d%H%M%S)
fi

# 创建新的前端静态文件目录
sudo mkdir -p /usr/share/nginx/html/open-webui

# 复制前端静态文件到合理的位置
echo "复制前端静态文件到 /usr/share/nginx/html/open-webui..."
sudo cp -r build/* /usr/share/nginx/html/open-webui

# 生成 Nginx 配置文件
echo "生成 Nginx 配置文件..."
NGINX_CONF="/etc/nginx/conf.d/open-webui.conf"
sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 80;
    server_name ai.inc localhost;

    # 配置前端静态文件
    location / {
        root /usr/share/nginx/html/open-webui;
        index index.html;
        try_files $uri /index.html;
    }

    # 配置后端 API 的反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOL

# 初始化后端 Python 的运行环境
echo "初始化后端 Python 运行环境..."
cd backend || exit
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..

echo "前端生成和后端初始化完成。"

# 配置 systemd 服务
SERVICE_FILE="/etc/systemd/system/open-webui.service"
CURRENT_DIR=$(pwd)
echo "创建 systemd 服务文件: $SERVICE_FILE"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Open WebUI Backend API Service
After=network.target

[Service]
WorkingDirectory=$CURRENT_DIR
ExecStart=$CURRENT_DIR/start_api.sh
Restart=always
User=$(whoami)
Group=$(whoami)

[Install]
WantedBy=multi-user.target
EOL

# 重新加载 systemd 并启用服务
echo "重新加载 systemd 并启用服务..."
sudo systemctl daemon-reload
sudo systemctl enable open-webui.service
sudo systemctl start open-webui.service

# 重启 Nginx 服务
echo "重启 Nginx 服务..."
sudo nginx -s reload

echo "systemd 服务配置完成并已启动。"

# 完成提示
echo "前端文件复制和 Nginx 配置完成。"
