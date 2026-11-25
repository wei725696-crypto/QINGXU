# 青序网站自动更新交接

## 已确定的部署信息

| 项目 | 值 |
| --- | --- |
| Git 仓库 | https://github.com/wei725696-crypto/QINGXU.git |
| 部署分支 | main |
| 现有网站目录 | /opt/qingxu-web/ |
| Compose 项目与服务 | qingxu-web / web |
| 当前容器名 | qingxu-web_web_1 |
| 默认内部健康地址 | http://127.0.0.1:18080/healthz |
| 公网地址 | http://101.133.164.180/qingxu/ |
| 更新方式 | 服务器 systemd timer 每次运行结束 60 秒后检查 Git |

由已有 SSH 权限的服务器管理员实施本文件中的步骤。本次交付只提供源码与配置，尚未登录服务器安装定时器。服务器运行实测完成后才算自动部署已启用。

采用服务器主动拉取公开 GitHub 仓库的方式，无需把服务器 SSH 私钥存入 GitHub。服务器必须能通过 HTTPS 访问 GitHub 和构建时使用的镜像仓库。如果以后将仓库改为私有，需要另配只读仓库认证。

main 上的新提交会自动成为部署目标。建议在其他分支修改和预览，确认后合入 main。自动部署只更新 Dockerfile、nginx.conf、index.html、app.js、style.css 五个运行文件。服务器现有 docker-compose.yml、.env、宿主机 Nginx 配置由管理员维护。涉及端口、数据库、Compose、自动更新程序本身的变更，要另做服务器配置更新。

## 一次性安装

适用于有 systemd 的 Ubuntu/Debian 服务器，需要 bash、git、curl、tar、flock、Docker 和现有 Compose。脚本优先使用旧版 docker-compose，找不到时使用 docker compose。固定 -p qingxu-web，复用现有服务。

先在服务器检查现有部署和健康接口。

```bash
cd /opt/qingxu-web
docker-compose -p qingxu-web ps
curl -fsS http://127.0.0.1:18080/healthz
```

健康接口应返回 ok。若现有宿主机端口不是 18080，将后续配置里的 HEALTH_URL 改为实测的本机地址。使用 Compose 插件的服务器把第一条命令中的 docker-compose 换成 docker compose。

如缺少依赖，可在 Ubuntu/Debian 上由管理员安装。

```bash
sudo apt-get update
sudo apt-get install -y git curl tar util-linux
```

首次安装时，在一个新目录拉取源码。本例 /opt/qingxu-deploy-tools 用来保留交接脚本，不是网站运行目录。

```bash
sudo git clone --branch main --single-branch https://github.com/wei725696-crypto/QINGXU.git /opt/qingxu-deploy-tools
cd /opt/qingxu-deploy-tools
git log -1 --oneline
sudo install -m 0755 ops/auto-update.sh /usr/local/lib/qingxu-auto-update.sh
sudo install -m 0644 ops/qingxu-auto-update.env.example /etc/default/qingxu-auto-update
sudo install -m 0644 ops/qingxu-auto-update.service /etc/systemd/system/qingxu-auto-update.service
sudo install -m 0644 ops/qingxu-auto-update.timer /etc/systemd/system/qingxu-auto-update.timer
```

已有 /opt/qingxu-deploy-tools 时，先检查其来源和工作区，再在该目录用 git pull --ff-only 更新。重新安装已有自动更新程序前，先停定时器，并备份 /etc/default/qingxu-auto-update 中的实际配置。

编辑 /etc/default/qingxu-auto-update，核对四项配置。

```dotenv
APP_DIR=/opt/qingxu-web
REPOSITORY=https://github.com/wei725696-crypto/QINGXU.git
DEPLOY_BRANCH=main
HEALTH_URL=http://127.0.0.1:18080/healthz
```

加载单元，手动运行一次并验收，成功后再启用定时器。

```bash
sudo systemctl daemon-reload
sudo systemctl start qingxu-auto-update.service
sudo journalctl -u qingxu-auto-update.service -n 80 --no-pager
curl -fsS http://127.0.0.1:18080/healthz
cat /opt/qingxu-web/.auto-deploy/last-success
sudo systemctl enable --now qingxu-auto-update.timer
systemctl list-timers qingxu-auto-update.timer --all
```

第一轮会构建并部署 main，成功日志为 Deployed 加提交号，last-success 应与 main 的提交号相同。首次启用会以 GitHub 中的五个文件更新现有网页，若服务器上改过这些文件，应先对照差异再开始。

## 更新和失败处理

每次检查先 fetch main。版本没有变化时退出。发现新版本时先备份五个运行文件并记录当前镜像 ID，然后构建和更新 web 服务。新镜像构建期间原容器继续提供页面，切换容器时可能有短暂访问中断。

更新后检查容器实际镜像 ID，并要求 HEALTH_URL 返回 ok。构建、启动或健康检查失败时，脚本尝试恢复原文件和原镜像，重新启动旧版并验证。回退也失败时，日志会出现 ROLLBACK NEEDS MANUAL ATTENTION，需要管理员处理。

同一个失败提交会记录在 .auto-deploy/failed-commit，后续定时检查会跳过它，避免每分钟反复构建。推送修复提交后会正常重试。管理员也可在修复环境问题后手动强制重试。

```bash
sudo systemctl stop qingxu-auto-update.timer
sudo systemctl stop qingxu-auto-update.service
sudo bash -c 'set -a; . /etc/default/qingxu-auto-update; set +a; /usr/bin/bash /usr/local/lib/qingxu-auto-update.sh --force'
sudo systemctl start qingxu-auto-update.timer
```

定时器以 root 权限执行构建，以复用已有 Docker 权限。拥有仓库 main 写入权限的人可以通过 Dockerfile 控制此次构建，仓库写权限应只授予可信的项目维护者。

## 验收清单

1. 手动运行服务成功，last-success 对应 GitHub main。
2. 原公网网址可打开，/qingxu/healthz 返回 ok。
3. 在本地预览一项可见的小修改，推送至 main。
4. 等待一个检查周期加镜像构建时间，确认公网页面出现该修改。
5. 日志中的部署提交号与 GitHub main 相同，原首页和气象接口仍可访问。

失败回退逻辑已用模拟 Docker/HTTP 命令进行本地流程验证。真实 Linux Docker 构建、systemd 安装、并发锁及公网端到端更新须在服务器验收；本交付电脑没有 Docker 或 systemd 运行环境。

## 查看、暂停和保存

```bash
sudo journalctl -u qingxu-auto-update.service -n 100 --no-pager
sudo systemctl disable --now qingxu-auto-update.timer
```

暂停定时器只停止后续检查，已经开始的更新可以等待完成，或由管理员执行 systemctl stop qingxu-auto-update.service 触发正常终止与回退。

保留 /opt/qingxu-web/.auto-deploy，里面有 Git 缓存、成功/失败提交号和每次更新的文件备份、镜像 ID。备份和 Docker 构建缓存会逐步占用磁盘，管理员应结合自己的保留策略维护；不要自动清理还需要回退的镜像。journalctl 日志按服务器已有日志策略保存。

自动更新脚本、service 或 timer 的变更，先暂停定时器并等待正在运行的服务完成，再从仓库拉取新版本并重新执行相应 install、daemon-reload 命令。正常的网页修改不需要重复安装。

## 参考

- systemd 定时器 https://www.freedesktop.org/software/systemd/man/249/systemd.timer.html
- Compose 项目名 https://docs.docker.com/compose/how-tos/project-name/
- Git fetch https://git-scm.com/docs/git-fetch
