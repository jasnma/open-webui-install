#!/bin/bash

# 设置环境变量
export HOST="127.0.0.1"
export PORT="8080"

# 后台转发 API 的地址
export OPENWEBUI_API_BASE_URL="http://127.0.0.1:8000/v1"
export OPENWEBUI_API_KEY="anykey"
export OPENWEBUI_DEFAULT_MODEL="deepseek-coder-7b-instruct"

# 切换到后端目录
cd open-webui/backend || exit

# 启动后台 API
source venv/bin/activate
start.sh
