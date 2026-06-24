# ✨ Epusdt Install

> 鱼肥肥 @pyufc  
> 面向官方 `GMWalletApp/epusdt` 的一键部署、接管、更新与运维脚本。

![Shell](https://img.shields.io/badge/Shell-Bash-1f6feb?style=for-the-badge)
![Epusdt](https://img.shields.io/badge/Epusdt-Official-10b981?style=for-the-badge)
![Systemd](https://img.shields.io/badge/Systemd-Auto_Start-f97316?style=for-the-badge)

## 🚀 一键入口

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh)
```

运行后按菜单选择安装、接管、更新、HTTPS、管理或卸载。

## 🧩 功能亮点

| 功能 | 说明 |
| --- | --- |
| ⚡ 一键安装 | 自动下载官方 release，完成部署并输出后台账号密码 |
| 🔁 一键更新 | 拉取官方最新版本，保留配置和数据库 |
| 🧲 接管旧实例 | 保留原有 `.env` 和 `sqlite` 数据，迁移到脚本托管 |
| 🔐 HTTPS | 域名校验、证书申请、Nginx 反代、强制 HTTPS |
| 🛠️ 日常管理 | 状态、日志、启动、停止、重启 |
| 🧹 一键卸载 | 删除服务、部署目录、证书与 Nginx 配置 |
| ♻️ 开机自启 | 全新安装或接管后自动写入 `systemd` 并启用 |

## 🧲 接管旧实例

适合已经手动部署过官方 `Epusdt`，并且还在使用本地 `sqlite` 的实例。

接管时会保留：

- 原来的 `.env`
- 原来的 `sqlite` 数据库
- 原来的安装目录
- 已有订单和后台数据

脚本会优先尝试识别并停止旧启动方式：

- 旧 `systemd` 服务
- 旧 Docker 容器
- 旧手动守护进程

如果端口仍被占用，脚本会提示先手动停止旧实例，再重新运行一键入口接管。

## 🔁 更新清理

一键更新会替换官方最新程序，并自动清理旧残留：

- 旧版前端目录 `www/`
- 上游遗留 `.env.example`
- 校验文件 `SHA256SUMS`
- 安装目录下遗留的 `epusdt-*.tar.gz`

配置文件、数据库和运行数据不会被清空。

## 🔐 域名模式

填写域名后会自动执行：

- 检查域名是否指向当前服务器
- 申请 HTTPS 证书
- 写入 Nginx 反代配置
- 强制跳转 `https://`

域名未指向当前服务器时，脚本会停止并给出明确提示。

## ✅ 安装结果

安装完成后会输出：

- 访问地址
- 后台账号
- 后台密码

默认后台账号：`admin`

## 📌 说明

本仓库只提供部署、接管和运维脚本。  
上游程序许可证与功能行为以官方 `GMWalletApp/epusdt` 为准。

## 📮 联系

`鱼肥肥 @pyufc`

`https://t.me/pyufc`
