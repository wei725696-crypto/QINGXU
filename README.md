# 青序 · 灌溉实验平台 V0.2

Docker 自托管交付为 0.2.1-demo，安装、启动、公网访问、配置与数据要求见 [DEPLOY.md](DEPLOY.md)。该交付保留本版演示功能，包含 Dockerfile、docker-compose.yml 和 .env.example。

已发布的 Git 仓库为 https://github.com/wei725696-crypto/QINGXU 。服务器 main 分支自动更新的配置、一次性安装和验收见 [ops/README.md](ops/README.md)。

按用户提供的四张参考图重做。侧栏仅五项：运行总览、灌溉控制、监测数据、告警记录、系统设置。设备运行状态保留在总览中，没有独立侧栏入口。

## 启动

这台 Windows 电脑已配置计划任务 `Qingxu-LocalPreview`，登录时通过本机 Python 运行 `local_preview.py --supervise`。预览地址为 http://127.0.0.1:18946/ ，健康接口为 http://127.0.0.1:18946/healthz 。

任务隐藏运行，守护程序在预览进程退出后等 2 秒重新启动它。任务同时配置每分钟的重复触发，运行中忽略新实例，停止后可补启动。允许电池供电运行，没有默认的任务执行时长上限。关闭浏览器或聊天窗口后，任务仍由 Windows 管理。关机、注销或休眠期间本机预览不可访问，恢复后可刷新页面。

日志位于 `%LOCALAPPDATA%\QingxuPreview\logs\preview.log` 和 `supervisor.log`，每类日志轮转保留约 4 MB。网页源码修改后刷新即可看到变化。移动项目目录或卸载 Python 时需要更新计划任务的路径。

在 PowerShell 中可以查看或手动启动预览。

```powershell
Get-ScheduledTask -TaskName Qingxu-LocalPreview
Start-ScheduledTask -TaskName Qingxu-LocalPreview
```

需要停用自动启动时执行以下命令。

```powershell
Disable-ScheduledTask -TaskName Qingxu-LocalPreview
Stop-ScheduledTask -TaskName Qingxu-LocalPreview
```

在其他电脑临时预览可在本目录运行 `python -m http.server 18946 --bind 127.0.0.1`，或直接打开 index.html。服务器部署仍按 DEPLOY.md 操作。

## 界面与交互

- 总览：四项指标、可随选中通道变化的 SVG 管路示意、田间环境、设备状态和运行事件。
- 控制：五路选择、自动按目标水量/手动按时限、模拟启停、进度环、水量累计和运行计时。达到目标或时限自动模拟停止。
- 监测：环境气象、ETa、土壤水分、灌溉水量四类曲线；24小时/7天切换；导出当前示例曲线 CSV。
- 告警：当前/历史记录、管理员确认示例。
- 设置：浏览器保存试验田名称与模拟最长开启时限。观察者不可修改或启停。

## 边界

全部数据为演示，尚无真实登录、后端或设备控制。角色选择只是界面预览，不能充当安全边界。未向气象 API 或主板发送请求，未部署。参考图里的90平方米及管路布局仅为示意，管径未确认。未知测量值在正式接口接入时用缺失状态呈现。

五路演示以2.4 L/min模拟流量累计；刷新重置会话。浏览器后台计时不适合真实控制，真实安全时限必须由主板执行。

本版未提供PWA安装、离线缓存或安装包，无外部字体/脚本依赖。已知气象 API 为 http://101.133.164.180/api/display/latest-weather-public?site_id=00001 ，后续通过接口适配层接入。

旧版三个文件保存在 backup-v01；新版预览为 preview-v02.png。

## 验证

JavaScript语法检查通过；浏览器验证五项导航、模拟启停及累计、观察者禁用控制、监测类别与时间切换、告警移入历史；390px手机总览无横向溢出。实际设备和账号后端未联调。
