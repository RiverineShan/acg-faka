# 异次元 A 卡：固定比例返佣版部署说明

## 版本基线

- 业务源码：官方完整 `3.0.0`，与本地 `3.0.0b.zip` 中对应文件内容一致。
- 返佣模式：后台配置 `promote_rebate_v1`、`promote_rebate_v2`、`promote_rebate_v3` 的固定比例三级返佣。
- 未合入 `3.1.9.zip`：该包只有两个依赖重构后架构的增量文件，不能单独把旧版升级成完整 3.1.9。

## GitHub 与 Zeabur

1. 将 `production-fixed-rebate` 分支推送到 GitHub。
2. 在 Zeabur 中将 Git 服务的部署分支切换到 `production-fixed-rebate`。
3. Zeabur 会自动识别仓库根目录的 `Dockerfile`。不要设置 `ZBPACK_IGNORE_DOCKERFILE=true`。
4. 在 Zeabur 为应用服务配置以下变量：

```text
DB_HOST=<Zeabur MySQL 服务主机名>
DB_PORT=<Zeabur MySQL 服务端口，通常为 3306>
DB_NAME=<数据库名>
DB_USER=<数据库用户>
DB_PASS=<数据库密码>
DB_PREFIX=acg_
```

5. 为下列目录挂载持久卷：

```text
/var/www/html/config
/var/www/html/kernel/Install
/var/www/html/runtime
/var/www/html/assets/cache
/var/www/html/app/Plugin
/var/www/html/app/Pay
/var/www/html/app/View/User/Theme
```

入口脚本只补齐卷中缺失的默认文件，并刷新系统自带的版本配置、WAF 配置与 Cartoon 核心主题。不会覆盖已有数据库配置、插件、支付模块或其他自定义主题。

`docker-compose.yml` 仅用于本地 Docker；Zeabur 当前不会直接使用 Compose 文件。

## Cloudflare

1. 先在 Zeabur 的 Domains 中绑定正式域名，等待 Zeabur 证书签发。
2. 按 Zeabur 提供的目标地址在 Cloudflare 建立 CNAME，并开启代理。
3. Cloudflare SSL/TLS 模式使用 `Full (strict)`。
4. 不要缓存后台、登录、下单、支付回调和 API 路径；动态页面缓存可能导致登录态或订单状态异常。

## 首次验收

1. 首页和后台均能打开。
2. 后台“其他设置”能看到三级推广返佣比例。
3. 创建三级测试账号链，并用测试支付验证三层账单金额。
4. 验证余额支付、第三方支付回调、自动/手动发货。
5. 确认重新部署后配置、插件、主题和安装锁仍存在。

生产切换前先备份 MySQL 和所有持久卷。旧版数据库不要直接套用新版数据库迁移。
