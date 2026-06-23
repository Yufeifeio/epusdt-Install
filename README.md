# Epusdt 一键部署脚本

仅提供中文说明。

`鱼肥肥 @pyufc`

## 说明

这是一个面向官方 `GMWalletApp/epusdt` 的一键部署仓库。

这个仓库只放部署脚本和中文文档，不打包业务源码，不改上游项目名称。

脚本特点：

- 菜单式安装，接近社区一键脚本使用习惯
- 自动下载官方 release
- 自动校验 `SHA256SUMS`
- 自动创建 `systemd` 服务
- 自动完成官方安装流程
- 自动回显后台初始账号密码
- 配置域名时自动申请证书并强制 `HTTPS`
- 兼容常见原生 `nginx` 和宝塔 `nginx`

## 一键命令

直接运行菜单：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh)
```

直接安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) install
```

一键更新：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) update
```

单独补 HTTPS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) https
```

## 现在的安装行为

不带域名：

- 默认安装目录优先取当前执行目录
- 默认开放一个空闲端口
- 安装完成后直接输出访问地址
- 脚本会自动完成官方初始化
- 最后直接输出后台账号和密码

带域名：

- 必须输入证书邮箱
- 会先检查域名是否真的解析到当前服务器
- 检查通过后自动申请证书
- 自动写入 `nginx` 配置
- 自动强制跳转到 `https://`
- 安装完成后直接输出后台账号和密码

## 后台账号说明

脚本安装完成后会自动调用官方接口获取一次性初始管理员密码，并直接回显：

- 账号固定为：`admin`
- 密码为安装时实时生成

建议你首次登录后立刻修改密码。

## 常用菜单

- `1. 开始部署`
- `2. 一键更新`
- `3. 配置 HTTPS`
- `4. 日常管理`
- `5. 检查版本`

## 可用参数

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
--api-rate-url URL
--nginx-conf-path PATH
--acme-email EMAIL
--non-interactive
--force
```

## 适合什么场景

- 你想用自己的 GitHub 发一个中文部署入口
- 你只想公开安装脚本，不想公开完整工程
- 你要给客户或团队一个统一命令
- 你要部署完成后直接拿到后台账号密码

## 联系方式

`鱼肥肥 @pyufc`

Telegram：

`https://t.me/pyufc`

## 版权说明

本仓库的脚本、文案、说明文件授权说明见：

- [版权声明.md](./版权声明.md)
- [发布前检查.md](./发布前检查.md)

上游程序许可证仍以官方 `GMWalletApp/epusdt` 为准。
