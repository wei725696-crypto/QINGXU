# 青序灌溉平台部署交付 · 0.2.1-demo

## 本次交付的功能

本包提供当前中文网页源码、Dockerfile、docker-compose.yml、Nginx 配置、.env.example 和本说明。可自行部署在你或同门授权管理的服务器上，并通过公网向电脑、手机提供网页访问。Nginx 等第三方软件按各自许可证使用。

页面包括运行总览、灌溉控制、监测数据、告警记录和系统设置。总览保留今日蒸散估算的 3.18 mm、3.06 mm 示例值。界面持续标注演示状态。

本版所有设备数据、曲线、启停和告警都是浏览器本地模拟。真实账号登录、服务器权限校验、设备数据入库、真实阀门控制、ETa 计算与手机安装包尚待开发。右上角“管理员／观察者”用于预览操作权限，任何访客都能切换，不能用作实际访问控制。本包目前不收集账号密码或设备密钥。

交付的是可构建镜像的源码包。当前交付电脑没有 Docker，未生成可直接 docker load 的镜像 tar，也未完成 Linux 容器启动实测。验证范围和结果见随包 VALIDATION.txt。

## 文件和依赖

| 文件 | 用途 |
| --- | --- |
| index.html、app.js、style.css | 完整网页源码，原生 HTML/CSS/JavaScript |
| Dockerfile | 使用官方 nginx:stable-alpine 构建，并在构建时执行 nginx -t |
| docker-compose.yml | 服务、端口、重启策略、资源上限、健康检查、日志轮转 |
| nginx.conf | 容器内 HTTP 服务和 /healthz 健康接口 |
| nginx-host-location.conf.example | 宿主机已有 Nginx 的 /qingxu/ 反向代理片段 |
| .env.example | 端口、绑定地址、基础镜像配置 |

服务端依赖为 Docker Engine 和 Docker Compose 插件，宿主机反向代理方式额外使用现有 Nginx。网页运行不需要安装 Node.js、Python、npm 包或 pip 包，无在线字体和 CDN 依赖。Node.js 只用于交付时的 JavaScript 语法检查。

第一次构建需要能下载官方 Nginx 基础镜像。后续运行不依赖 Docker Hub 网络。可在 .env 中将 NGINX_IMAGE 改为服务器可访问的受信镜像仓库地址或固定 digest。stable-alpine 是浮动标签，重建时可能获得新版基础镜像。

## 服务器要求

以下是低访问量静态演示网页的部署预算，属于工程估算，尚未进行并发压测。

| 项目 | 需求 |
| --- | --- |
| CPU | 整机建议至少 1 vCPU，并为容器留出 0.5 vCPU 额度 |
| 内存 | 整机建议至少 1 GB，除已有业务外留出约 256 MB 可用内存 |
| 容器限制 | Compose 设置 128 MB 内存、0.5 CPU |
| 磁盘 | 建议至少 1 GB 空闲，包含 Docker 镜像、构建缓存和轮转日志 |
| GPU | 无需 GPU |
| Linux | 建议 Ubuntu 22.04/24.04 LTS 或 Debian 12，使用该发行版支持的 Docker Engine 和 Compose 插件 |
| CPU 架构 | Linux amd64（x86_64）或 arm64（aarch64），在对应架构服务器原生构建 |
| 网络 | 首次拉取镜像的出网能力，以及所选公网入口的入站访问 |

源码由静态资源组成，基础镜像提供 amd64 和 arm64 版本。两种 Linux 架构均未在本交付电脑运行实测。服务器已运行其他应用时，以上空闲资源应在原业务预算之外预留。

## 安装与启动

以将本包解压到 /opt/qingxu-web 为例。先让服务器管理员确认现有 Docker 安装情况。

```bash
cd /opt/qingxu-web
docker version
docker compose version
```

如果尚未安装 Docker，请按对应系统的官方安装文档完成 Docker Engine 和 Compose 插件安装。已有 Docker 的服务器保留现有安装，避免更改同门其他容器环境。

- Ubuntu 安装文档 https://docs.docker.com/engine/install/ubuntu/
- Debian 安装文档 https://docs.docker.com/engine/install/debian/
- Compose 插件文档 https://docs.docker.com/compose/install/linux/

以下命令要求当前账号有 Docker 使用权限，否则由管理员执行。

```bash
cd /opt/qingxu-web
cp .env.example .env
docker compose config
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:18080/healthz
```

最后一条请求应返回 ok。首次启动约 15 秒后查看 docker compose ps，应显示 healthy。构建失败时先看镜像拉取是否成功，再执行 docker compose logs --tail=100 web 检查日志。

容器内监听 8080。默认映射到服务器 127.0.0.1:18080，适合由同一台服务器的现有 Nginx 提供公网入口。这个默认地址只能在服务器本机访问。

## 使用现有服务器 Nginx 对外发布

建议在原网站增加 /qingxu/ 路径。将 nginx-host-location.conf.example 的内容加入现有网站的 server {} 内，保持原有首页与 /api/ 配置。该文件是配置片段，不能单独作为顶层 Nginx 配置。

宿主机 Nginx 代理目标为 http://127.0.0.1:18080/。proxy_pass 末尾的斜杠用于去掉 /qingxu/ 前缀，使 CSS、JavaScript 和健康接口正确定位。修改 HOST_PORT 时同时修改代理目标。

由有权限的管理员测试、重新加载配置。

```bash
sudo nginx -t
sudo systemctl reload nginx
curl -fsS http://127.0.0.1/qingxu/healthz
```

如果现有网站按域名匹配，请在 curl 中使用实际域名或正确的 Host 请求头。宝塔等面板管理的 Nginx，应使用对应面板的网站配置和重载入口。

服务器仍为 101.133.164.180 时，配置完成后可访问 http://101.133.164.180/qingxu/ 。该公网路径截至打包时尚未部署验证。手机使用手机浏览器打开同一公网地址，服务器需要持续运行。

有域名和证书时，将此片段放进域名的 HTTPS 网站，访问 https://你的域名/qingxu/。证书配置、域名解析及备案按服务器已有环境和运营要求由管理员处理。

## 直接使用独立端口对外访问

如果管理员希望先通过端口验收，编辑 .env。

```dotenv
BIND_ADDRESS=0.0.0.0
HOST_PORT=18080
NGINX_IMAGE=nginx:stable-alpine
```

执行 docker compose up -d --build，并在阿里云安全组及服务器防火墙允许所需来源访问 TCP 18080。访问 http://服务器公网IP:18080/，本例为 http://101.133.164.180:18080/。选择 18080 是为了避开已有网站占用的 80/443 端口。

默认方案通过原网站 80/443 反向代理，无需向公网开放 18080。如果宿主机 Nginx 自身在另一容器内运行，则 127.0.0.1 指向该 Nginx 容器，需要管理员另配容器网络与代理地址。

## 配置和数据要求

| 配置／服务 | 本版要求 |
| --- | --- |
| BIND_ADDRESS | 默认 127.0.0.1，同机反向代理。直接公网访问时改为 0.0.0.0 |
| HOST_PORT | 默认 18080，可换空闲端口，代理地址需同步修改 |
| NGINX_IMAGE | 默认 nginx:stable-alpine，可指定受信基础镜像或 digest |
| 数据库 | 无需，本版没有服务器历史数据持久化 |
| Redis | 无需 |
| 外部 API | 本版不调用外部 API，无 API 密钥配置 |
| 数据导入／数据库迁移 | 无需，页面自带演示序列 |
| 持久化卷 | 无需 |

.env 由 Compose 读取，用来配置部署参数。修改 .env 不会自动把网页切换为真实设备模式。

已知气象接口为 http://101.133.164.180/api/display/latest-weather-public?site_id=00001，留作后续联调参考，本包未接入它。真实灌溉上报与控制 API 还需要另行实现。

长期保留解压的项目目录、.env、宿主机反向代理配置，以及启用 HTTPS 后的证书和续期配置。它们用于重建或恢复部署。

试验田名称和模拟最长开启时限保存在每个浏览器的 localStorage。更换浏览器、清理网站数据或更换网址后，这些设置不会自动迁移。模拟累计量和告警处理结果刷新会重置。

应用没有需要备份的服务器业务数据目录。容器日志输出至 Docker 日志驱动，限制为 3 个各 10 MB 的文件。需要留存运维记录时，由服务器已有日志系统采集。

## 验收请求和页面操作

本版无需登录，没有测试账号。右上角身份选择仅作页面演示。公开发布后，持有地址的访客可查看和操作演示界面。

在服务器上验证。

```bash
curl -fsS http://127.0.0.1:18080/healthz
curl -fsS http://127.0.0.1:18080/ -o /dev/null
curl -fsS http://127.0.0.1:18080/app.js -o /dev/null
curl -fsS http://127.0.0.1:18080/style.css -o /dev/null
```

依次应返回 ok 和三个成功的 HTTP 请求。/healthz 只验证 HTTP 服务存活，不代表传感器、主板或网关在线。

若使用公网 /qingxu/ 入口，在另一台电脑或手机验证 /qingxu/healthz 返回 ok，然后打开网页，依次检查以下操作。

1. 五个导航可以切换，页面持续显示演示标识。
2. 总览显示蒸散估算两行示例值，单位 mm。
3. 管理员身份下启动和停止模拟灌溉，进度与累计量变化。
4. 切换观察者后，启停按钮禁用。
5. 监测数据切换类别和时间范围，CSV 可以下载。
6. 手机布局可以查看并操作页面。

验收只证明本版演示网页的部署与交互。后续正式版需增加真实登录、服务端权限校验、数据库、真实设备遥测与命令回执，并重新进行验收。

## 维护、更新和离线镜像

```bash
# 查看状态和日志
docker compose ps
docker compose logs --tail=100 web
# 更新源码后重新构建
docker compose up -d --build
# 停止服务
docker compose down
```

容器配置为 unless-stopped。由 Docker 守护进程管理的容器会按该策略重启，服务器应启用 Docker 服务开机启动。

需要离线交付时，在一台有 Docker、网络可用且与目标服务器同 CPU 架构的机器构建和导出。

```bash
docker compose build
docker save -o qingxu-web-0.2.1-demo-linux.tar qingxu-web:0.2.1-demo
```

将 tar 和本源码包一起传到目标服务器，配置 .env 后导入、启动。

```bash
docker load -i qingxu-web-0.2.1-demo-linux.tar
docker compose up -d --no-build --pull never
```

amd64 和 arm64 的原生构建镜像应分别导出，不要把单架构 tar 当作跨架构镜像。

如服务器已经有 Nginx，也可直接将 index.html、app.js、style.css 放到独立静态网站目录，配置静态访问。该方式无需 Docker，本包提供相同的完整网页源码。

## 技术参考

- Nginx 官方镜像与架构 https://hub.docker.com/_/nginx
- Docker Compose 构建和启动 https://docs.docker.com/guides/docker-compose/common-questions/
- Nginx 路径代理规则 https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass
