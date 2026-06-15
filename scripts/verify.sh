#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 未安装，请先安装 $1"
        exit 1
    fi
    log "✓ $1 已安装"
}

print_header "环境检查"

check_command python3
check_command node
check_command npm

if command -v docker &> /dev/null && command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    log "✓ Docker Compose 已安装"
else
    warn "Docker 未安装，将跳过 Docker 配置验证"
    SKIP_DOCKER=true
fi

cd "$ROOT_DIR"

print_header "步骤 1/3: 后端验证"

log "检查后端依赖..."
cd "$ROOT_DIR/backend"

if [ ! -d ".venv" ]; then
    log "创建 Python 虚拟环境..."
    python3 -m venv .venv
fi

source .venv/bin/activate

log "安装 Python 依赖..."
pip install -r requirements.txt -q

log "启动后端服务进行健康检查..."
python run.py &
BACKEND_PID=$!

log "等待后端服务启动..."
sleep 3

log "检查健康接口..."
for i in {1..10}; do
    if curl -s http://127.0.0.1:5000/api/health | grep -q "ok"; then
        success "后端健康检查通过"
        break
    fi
    if [ $i -eq 10 ]; then
        error "后端健康检查失败"
        kill $BACKEND_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

log "检查 API 接口..."
curl -s http://127.0.0.1:5000/api/spaces > /dev/null
success "后端 API 接口正常"

log "停止后端服务..."
kill $BACKEND_PID 2>/dev/null || true
wait $BACKEND_PID 2>/dev/null || true

deactivate

print_header "步骤 2/3: 前端构建验证"

log "检查前端依赖..."
cd "$ROOT_DIR/frontend"

if [ ! -d "node_modules" ]; then
    log "安装 npm 依赖..."
    npm install
fi

log "构建前端..."
npm run build

if [ -d "dist" ] && [ -f "dist/index.html" ]; then
    success "前端构建成功"
else
    error "前端构建失败，dist 目录不存在"
    exit 1
fi

print_header "步骤 3/3: Docker 配置验证"

if [ "$SKIP_DOCKER" = true ]; then
    warn "跳过 Docker 配置验证"
else
    cd "$ROOT_DIR"

    log "验证 docker-compose.yml 配置..."
    if docker compose config > /dev/null 2>&1; then
        success "docker-compose.yml 配置有效"
    else
        error "docker-compose.yml 配置无效"
        exit 1
    fi

    log "检查后端 Dockerfile..."
    if [ -f "$ROOT_DIR/backend/Dockerfile" ]; then
        success "后端 Dockerfile 存在"
    else
        error "后端 Dockerfile 不存在"
        exit 1
    fi

    log "检查前端 Dockerfile..."
    if [ -f "$ROOT_DIR/frontend/Dockerfile" ]; then
        success "前端 Dockerfile 存在"
    else
        error "前端 Dockerfile 不存在"
        exit 1
    fi

    log "检查 .dockerignore 文件..."
    for dir in backend frontend; do
        if [ -f "$ROOT_DIR/$dir/.dockerignore" ]; then
            success "$dir/.dockerignore 存在"
        else
            warn "$dir/.dockerignore 不存在"
        fi
    done
fi

print_header "验证完成"
success "所有验证步骤已通过！"
echo ""
echo "后端: http://127.0.0.1:5000"
echo "前端开发: http://127.0.0.1:5173"
echo "Docker 启动: docker compose up --build"
echo "Docker 访问: http://127.0.0.1:8080"
echo ""
