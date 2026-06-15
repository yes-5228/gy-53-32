# 停车场收费系统

基于 Flask + Vue 的停车场收费系统，包含车位状态监控、月卡办理、临时停车计费和电子发票开具。

## 功能模块

- 车位状态监控：查看车位总数、空闲、占用、预约、维护状态，支持更新车位状态。
- 月卡办理：登记车主、手机号、车牌、有效期和费用，支持月卡状态维护。
- 临时停车计费：登记车辆入场、按 15 分钟免费和 8 元/小时规则试算，支持离场结算。
- 电子发票开具：基于已结算停车订单生成电子发票记录。

## 项目结构

```text
backend/
  app/
    routes/       Flask 蓝图接口
    services/     计费、发票等业务服务
    database.py   SQLite 初始化和连接
  run.py
  Dockerfile
frontend/
  src/
    api/          前端请求封装
    components/   通用组件
    pages/        业务页面
    styles/       全局样式
  Dockerfile
  nginx.conf
docker-compose.yml
```

## 一键本地验证

运行以下命令即可完成环境检查、后端验证、前端构建验证和 Docker 容器端到端验证：

```bash
npm run verify
```

或直接运行脚本：

```bash
bash scripts/verify.sh
```

该命令会自动完成以下 **4 个阶段** 的验证：

### 阶段 1：环境检查
检查 Python3、Node、NPM、Docker 是否正确安装

### 阶段 2：后端验证
- 创建 Python 虚拟环境
- 安装 pip 依赖
- 启动后端服务（仅清理本次启动的进程，不影响其他服务）
- 健康检查（HTTP 状态码 2xx，超时 30 秒）
- API 接口验证
- 停止后端服务

### 阶段 3：前端构建验证
- 安装 npm 依赖
- 执行 `npm run build` 构建
- 验证 `dist/index.html` 构建产物

### 阶段 4：Docker 容器验证
- 验证 `docker-compose.yml` 配置有效性
- 检查前后端 Dockerfile 是否存在
- **实际构建镜像**（`docker compose build --no-cache`）
- **实际启动容器**（检查启动命令返回值成功后再继续）
- 检查容器运行状态
- 后端容器健康检查（HTTP 状态码 2xx，超时 60 秒）
- 前端容器健康检查（HTTP 状态码 2xx，超时 30 秒）
- 停止并清理容器

验证结束后会显示每一步的 **通过/失败/跳过汇总结果**。如验证过程中脚本异常中断或用户按 Ctrl+C，会自动执行资源清理（进程、容器）。

## 本地开发

后端：

```bash
npm run start:backend
```

前端：

```bash
npm run start:frontend
```

访问 `http://127.0.0.1:5173`，后端接口为 `http://127.0.0.1:5000/api`。

## Docker 启动

```bash
npm run docker:up
```

停止：

```bash
npm run docker:down
```

访问 `http://127.0.0.1:8080`。前端 Nginx 会将 `/api` 代理到后端 Flask 服务。

## 验证接口

```bash
curl http://127.0.0.1:5000/api/health
curl http://127.0.0.1:5000/api/spaces
```
