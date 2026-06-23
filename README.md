# Epusdt 一键部署脚本

仅提供中文说明。

品牌：`鱼肥肥`

联系方式：`https://t.me/pyufc`

## 项目简介

这是一个面向 `Epusdt` 的一键部署脚本仓库，定位是：

- 提供中文安装说明
- 提供单文件一键部署脚本
- 提供更新、重启、状态、日志等常用运维入口
- 不提供业务源码开放授权

如果你在部署、更新、服务启动、反向代理配置方面遇到问题，可以通过下面方式联系：

- Telegram：`https://t.me/pyufc`
- 品牌支持：`鱼肥肥`

这个仓库可以是 `public`，但它不是开源协作仓库。

## 适用场景

- 想用自己的 GitHub 发一个中文安装入口
- 想给客户、用户、同事一个统一安装命令
- 不想像社区仓那样维护一大套公开源码项目
- 只想公开文档和安装脚本

## 重要说明

本仓库当前脚本默认直接下载官方 `GMWalletApp/epusdt` release 来安装。

这样做的原因很简单：

- 官方 `Epusdt` 仓库本身是 `GPLv3`
- 如果你把它的二进制重新上传到你自己的 release 再分发，许可证义务会更复杂
- 最稳妥的做法是：
  - 你的仓库只放 README 和安装脚本
  - 安装脚本直接拉取官方 release

如果你后面一定要改成“从你自己的 release 下载二进制”，请先自己确认许可证和分发义务。

## 功能列表

- 自动识别 `amd64 / arm64`
- 自动下载官方最新 release
- 自动校验 `SHA256SUMS`
- 自动创建安装目录
- 自动生成 `.env`
- 自动创建 `systemd` 服务
- 可选自动生成 `nginx` 反代配置
- 支持以下命令：
  - `install`
  - `update`
  - `restart`
  - `stop`
  - `status`
  - `logs`

## 快速开始

安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) install
```

更新：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) update
```

查看状态：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) status
```

查看日志：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) logs
```

## 售后与支持说明

本仓库由 `鱼肥肥` 提供中文分发和部署入口整理。

支持范围建议理解为：

- 安装脚本使用说明
- 常规部署排错
- `systemd` 服务问题排查
- `nginx` 反向代理基础问题

联系地址：

- `https://t.me/pyufc`

## 常用参数

安装时支持这些参数：

```bash
--install-dir PATH
--service-name NAME
--service-user USER
--service-group GROUP
--version VERSION|latest
--domain DOMAIN
--port PORT
--bind-addr ADDR
--app-name NAME
--app-uri URI
--api-rate-url URL
--with-nginx 1|0|auto
--nginx-conf-path PATH
--non-interactive
--force
```

带域名安装示例：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) install \
  --domain pay.example.com \
  --with-nginx 1
```

指定版本安装示例：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) install \
  --version v1.0.8
```

## 默认行为

- 默认安装目录：`/opt/epusdt`
- 默认服务名：`epusdt`
- 默认服务用户：`epusdt`
- 默认版本：官方最新 release
- 默认端口：从 `8000` 开始自动找空闲端口
- 配了域名且启用 `nginx` 时，默认绑定 `127.0.0.1`
- 不配域名时，默认绑定 `0.0.0.0`

## 仓库建议结构

当前模板建议你上传这些文件：

- `README.md`
- `install.sh`
- `版权声明.md`
- `发布前检查.md`

这就够了，不需要额外把程序源码、静态文件、二进制都塞进仓库。

## 当前发布信息

- 品牌：`鱼肥肥`
- 联系方式：`https://t.me/pyufc`
- GitHub 仓库：`https://github.com/Yufeifeio/epusdt-Install`
- 默认安装来源：官方 `GMWalletApp/epusdt` release

## 版权

本仓库自身脚本和文案的授权说明，见：

- [版权声明.md](./版权声明.md)
- [发布前检查.md](./发布前检查.md)
