# Epusdt Install

`鱼肥肥 @pyufc`

面向官方 `GMWalletApp/epusdt` 的一键部署仓库。

## 一键命令

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh)
```

## 支持能力

- 一键安装
- 一键更新
- 一键补 HTTPS
- 一键卸载
- 服务状态 / 日志 / 重启 / 停止
- 自动输出后台账号密码
- 自动适配常见 `nginx` 和宝塔环境

## 安装结果

安装完成后会直接输出：

- 访问地址
- 后台账号
- 后台密码

默认后台账号：

`admin`

## 域名模式

填写域名时会自动执行：

- 检查域名是否指向当前服务器
- 申请证书
- 写入 `nginx`
- 强制跳转 `https://`

如果域名没有指向当前服务器，脚本会直接停止，不会乱改配置。

## 常用命令

进入菜单：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh)
```

直接安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) install
```

直接更新：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) update
```

补 HTTPS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) https
```

卸载：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) uninstall
```

## 联系

`鱼肥肥 @pyufc`

`https://t.me/pyufc`

上游程序许可证仍以官方 `GMWalletApp/epusdt` 为准。
