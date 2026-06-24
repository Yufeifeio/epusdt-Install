# Epusdt Install

`鱼肥肥 @pyufc`

面向官方 `GMWalletApp/epusdt` 的一键部署仓库。

## 一键命令

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh)
```

## 支持能力

- 一键安装
- 接管旧实例
- 一键更新
- 一键补 HTTPS
- 一键卸载
- 服务状态 / 日志 / 重启 / 停止
- 自动输出后台账号密码
- 自动适配常见 `nginx` 和宝塔环境
- 安装或接管后自动设为开机自启

## 接管旧实例

如果别人之前已经手动部署过官方 `Epusdt`，并且还在继续使用本地 `sqlite`，现在可以直接接管到脚本里：

- 不清空原有数据
- 不重做安装流程
- 保留原来的 `.env`
- 保留原来的 `sqlite` 数据库
- 自动写入 `systemd`
- 自动设为开机自启
- 后续可以直接使用脚本一键更新

命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) adopt
```

## 更新效果

执行一键更新时，除了替换官方最新程序，还会自动清理这些旧残留：

- 旧版前端目录 `www/`
- 上游遗留 `.env.example`
- 校验文件 `SHA256SUMS`
- 安装目录下遗留的 `epusdt-*.tar.gz`

这样更新后目录会更干净，不会一直堆无用文件。

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

接管旧实例：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Yufeifeio/epusdt-Install/main/install.sh) adopt
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
