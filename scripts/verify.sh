#!/usr/bin/env bash

set -e

# ====================================================================
# 本地验证脚本 - 停车场收费系统
#
# 功能：
#   1. 环境检查：验证 Python3、Node、NPM、Docker 是否安装
#   2. 后端验证：创建虚拟环境、安装依赖、启动服务、健康检查、API 验证
#   3. 前端构建验证：安装依赖、执行构建、验证构建产物
#   4. Docker 容器验证：验证 compose 配置、构建镜像、启动容器、
#                      检查容器运行状态、容器健康检查、停止清理
#
# 使用方法：
#   bash scripts/verify.sh
#   或
#   npm run verify
# ====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BACKEND_PID=""
DOCKER_STARTED=false

RESULT_STEPS=()
RESULT_STATUSES=()
RESULT_DETAILS=()

trap cleanup EXIT INT TERM

cleanup() {
    echo ""
    echo -e "${YELLOW}[CLEANUP]${NC} 正在清理所有资源..."

    if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo -e "${YELLOW}[CLEANUP]${NC} 停止后端服务 (PID: $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null || true
        sleep 1
        if kill -0 "$BACKEND_PID" 2>/dev/null; then
            kill -9 "$BACKEND_PID" 2>/dev/null || true
        fi
    fi

    if [ "$DOCKER_STARTED" = true ]; then
        echo -e "${YELLOW}[CLEANUP]${NC} 停止并清理 Docker 容器..."
        cd "$ROOT_DIR"
        docker compose down -v --remove-orphans 2>/dev/null || true
        docker rm -f parking_backend parking_frontend 2>/dev/null || true
    fi

    if [ -n "$VIRTUAL_ENV" ] && command -v deactivate &> /dev/null; then
        deactivate 2>/dev/null || true
    fi

    echo -e "${GREEN}[CLEANUP]${NC} 资源清理完成"
}

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

record_result() {
    local step="$1"
    local status="$2"
    local detail="$3"
    RESULT_STEPS+=("$step")
    RESULT_STATUSES+=("$status")
    RESULT_DETAILS+=("$detail")
}

mark_pass() {
    record_result "$1" "PASS" "$2"
}

mark_fail() {
    record_result "$1" "FAIL" "$2"
}

mark_skip() {
    record_result "$1" "SKIP" "$2"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

check_command() {
    local name="$1"
    if ! command -v "$name" &> /dev/null; then
        error "$name 未安装，请先安装 $name"
        mark_fail "环境检查.${name}" "未安装"
        print_summary
    fi
    log "✓ $name 已安装"
}

check_with_timeout() {
    local url="$1"
    local timeout_sec="$2"
    local description="$3"

    local start_time=$(date +%s)
    local end_time=$((start_time + timeout_sec))
    local http_code

    while [ $(date +%s) -lt $end_time ]; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            return 0
        fi
        sleep 1
    done

    error "$description 超时 (${timeout_sec}s, 最后状态码: ${http_code})"
    return 1
}

print_summary() {
    print_header "验证结果汇总"

    local pass_count=0
    local fail_count=0
    local skip_count=0
    local i=0

    while [ $i -lt ${#RESULT_STEPS[@]} ]; do
        local step="${RESULT_STEPS[$i]}"
        local status="${RESULT_STATUSES[$i]}"
        local detail="${RESULT_DETAILS[$i]}"

        case "$status" in
            PASS)
                pass_count=$((pass_count + 1))
                printf "  ${GREEN}✓ PASS${NC}  %-40s %s\n" "$step" "$detail"
                ;;
            FAIL)
                fail_count=$((fail_count + 1))
                printf "  ${RED}✗ FAIL${NC}  %-40s %s\n" "$step" "$detail"
                ;;
            SKIP)
                skip_count=$((skip_count + 1))
                printf "  ${YELLOW}○ SKIP${NC}  %-40s %s\n" "$step" "$detail"
                ;;
        esac
        i=$((i + 1))
    done

    echo ""
    echo "------------------------------------------"
    printf "总计: ${GREEN}通过 %d${NC}, ${RED}失败 %d${NC}, ${YELLOW}跳过 %d${NC}\n" "$pass_count" "$fail_count" "$skip_count"
    echo "------------------------------------------"

    if [ "$fail_count" -gt 0 ]; then
        echo ""
        error "有 ${fail_count} 项验证失败，请检查后重试"
        exit 1
    else
        echo ""
        printf "${GREEN}[SUCCESS]${NC} 所有验证步骤已通过！\n"
        echo ""
        echo "后端: http://127.0.0.1:5000"
        echo "前端开发: http://127.0.0.1:5173"
        echo "Docker 启动: npm run docker:up"
        echo "Docker 访问: http://127.0.0.1:8080"
        echo ""
    fi
}

print_header "环境检查"

check_command python3
check_command node
check_command npm

if command -v docker &> /dev/null && (command -v docker-compose &> /dev/null || docker compose version &> /dev/null); then
    log "✓ Docker Compose 已安装"
    mark_pass "环境检查.Docker" "已安装"
else
    warn "Docker 未安装，将跳过 Docker 配置验证"
    SKIP_DOCKER=true
    mark_skip "环境检查.Docker" "未安装"
fi

mark_pass "环境检查.Python" "已安装"
mark_pass "环境检查.Node" "已安装"
mark_pass "环境检查.NPM" "已安装"

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
if pip install -r requirements.txt -q 2>&1; then
    mark_pass "后端验证.依赖安装" "成功"
else
    mark_fail "后端验证.依赖安装" "失败"
    print_summary
fi

log "启动后端服务进行健康检查..."
python run.py &
BACKEND_PID=$!
log "后端服务已启动 (PID: $BACKEND_PID)"

sleep 2
if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    error "后端服务启动失败，进程已退出"
    mark_fail "后端验证.服务启动" "进程异常退出"
    BACKEND_PID=""
    print_summary
fi

log "等待后端服务就绪..."
if check_with_timeout "http://127.0.0.1:5000/api/health" 30 "后端健康检查"; then
    success "后端健康检查通过"
    mark_pass "后端验证.健康检查" "200 OK"
else
    mark_fail "后端验证.健康检查" "超时或失败"
    print_summary
fi

log "检查 API 接口..."
if curl -s --max-time 5 http://127.0.0.1:5000/api/spaces > /dev/null 2>&1; then
    success "后端 API 接口正常"
    mark_pass "后端验证.API接口" "正常"
else
    mark_fail "后端验证.API接口" "失败"
    print_summary
fi

log "停止后端服务..."
kill "$BACKEND_PID" 2>/dev/null || true
wait "$BACKEND_PID" 2>/dev/null || true
BACKEND_PID=""

deactivate

print_header "步骤 2/3: 前端构建验证"

log "检查前端依赖..."
cd "$ROOT_DIR/frontend"

if [ ! -d "node_modules" ]; then
    log "安装 npm 依赖..."
    if npm install --no-audit --no-fund 2>&1; then
        mark_pass "前端验证.依赖安装" "成功"
    else
        mark_fail "前端验证.依赖安装" "失败"
        print_summary
    fi
else
    mark_pass "前端验证.依赖检查" "已存在"
fi

log "构建前端..."
if npm run build 2>&1; then
    if [ -d "dist" ] && [ -f "dist/index.html" ]; then
        success "前端构建成功"
        mark_pass "前端验证.构建" "成功"
    else
        error "前端构建失败，dist 目录不存在"
        mark_fail "前端验证.构建产物" "dist/index.html 不存在"
        print_summary
    fi
else
    mark_fail "前端验证.构建" "失败"
    print_summary
fi

print_header "步骤 3/3: Docker 容器验证"

if [ "$SKIP_DOCKER" = true ]; then
    warn "跳过 Docker 容器验证"
    mark_skip "Docker验证.配置检查" "Docker 未安装"
    mark_skip "Docker验证.镜像构建" "Docker 未安装"
    mark_skip "Docker验证.容器启动" "Docker 未安装"
    mark_skip "Docker验证.后端健康检查" "Docker 未安装"
    mark_skip "Docker验证.前端健康检查" "Docker 未安装"
else
    cd "$ROOT_DIR"

    log "验证 docker-compose.yml 配置..."
    if docker compose config > /dev/null 2>&1; then
        success "docker-compose.yml 配置有效"
        mark_pass "Docker验证.配置检查" "有效"
    else
        error "docker-compose.yml 配置无效"
        mark_fail "Docker验证.配置检查" "无效"
        print_summary
    fi

    log "检查 Dockerfile 存在性..."
    for dir in backend frontend; do
        if [ -f "$ROOT_DIR/$dir/Dockerfile" ]; then
            mark_pass "Docker验证.${dir}Dockerfile" "存在"
        else
            error "$dir/Dockerfile 不存在"
            mark_fail "Docker验证.${dir}Dockerfile" "不存在"
            print_summary
        fi
    done

    log "构建 Docker 镜像..."
    DOCKER_STARTED=true
    if docker compose build --no-cache 2>&1; then
        success "Docker 镜像构建成功"
        mark_pass "Docker验证.镜像构建" "成功"
    else
        error "Docker 镜像构建失败"
        mark_fail "Docker验证.镜像构建" "失败"
        DOCKER_STARTED=false
        print_summary
    fi

    log "启动 Docker 容器..."
    if docker compose up -d 2>&1; then
        sleep 3
        log "启动命令执行成功，检查容器运行状态..."
        if docker compose ps --format '{{.Service}}: {{.State}}' | grep -q "running"; then
            success "Docker 容器已启动"
            mark_pass "Docker验证.容器启动" "运行中"
        else
            error "Docker 容器启动后状态异常"
            mark_fail "Docker验证.容器启动" "容器未处于 running 状态"
            docker compose logs 2>&1 | head -50 || true
            print_summary
        fi
    else
        error "Docker 容器启动命令执行失败"
        mark_fail "Docker验证.容器启动" "启动命令失败"
        docker compose logs 2>&1 | head -50 || true
        print_summary
    fi

    log "等待后端容器服务就绪..."
    if check_with_timeout "http://127.0.0.1:5000/api/health" 60 "后端容器健康检查"; then
        success "后端容器健康检查通过"
        mark_pass "Docker验证.后端健康检查" "200 OK"
    else
        mark_fail "Docker验证.后端健康检查" "超时或失败"
        docker compose logs backend 2>&1 | tail -30 || true
        print_summary
    fi

    log "等待前端容器服务就绪..."
    if check_with_timeout "http://127.0.0.1:8080" 30 "前端容器健康检查"; then
        success "前端容器健康检查通过"
        mark_pass "Docker验证.前端健康检查" "200 OK"
    else
        mark_fail "Docker验证.前端健康检查" "超时或失败"
        docker compose logs frontend 2>&1 | tail -30 || true
        print_summary
    fi

    log "停止 Docker 容器..."
    docker compose down -v 2>&1
    DOCKER_STARTED=false
    success "Docker 容器已停止并清理"
fi

print_summary
