#!/bin/sh
set -e

cd /var/www/html

# 这些目录都会在运行期被安装器、插件市场、上传接口、模板引擎、
# WAF/请求日志、在线更新等逻辑写入。容器启动时再修一次，是为了兼容
# 已存在的 named volume 或从旧版本 docker-compose 迁移过来的 volume。
mkdir -p \
    assets/cache \
    app/Pay \
    app/Plugin \
    app/View/User/Theme \
    config \
    kernel/Install/OS \
    kernel/Install/Update \
    runtime/log \
    runtime/plugin \
    runtime/request \
    runtime/tmp \
    runtime/view \
    runtime/waf

# Zeabur 等平台的持久化卷初次挂载时可能是空目录，会把镜像内的默认配置、
# 默认主题和安装资源“盖掉”。这里只恢复基础配置，绝不覆盖安装后写入的
# config/database.php，避免把真实数据库连接顶回示例值。
# app.php only contains the deployed application version. Always refresh it so
# a persistent volume cannot leave the dashboard reporting an older release.
cp -a /usr/local/share/acg-faka/default-config/app.php config/app.php

if [ ! -f config/dependencies.php ]; then
    cp -a /usr/local/share/acg-faka/default-config/dependencies.php config/dependencies.php
fi

if [ ! -d config/waf ] || [ -z "$(ls -A config/waf 2>/dev/null)" ]; then
    mkdir -p config/waf
    cp -a /usr/local/share/acg-faka/default-waf/. config/waf/
fi

if [ ! -f app/View/User/Theme/Cartoon/Config.php ]; then
    cp -a /usr/local/share/acg-faka/default-theme/. app/View/User/Theme/
fi

# Installer files are version-owned. Refresh them for new installations while
# preserving the generated Lock file and update workspace in the volume.
cp -a /usr/local/share/acg-faka/default-install/. kernel/Install/

# Compiled templates are generated code and must not survive an application
# upgrade. Leave logs, uploads and other runtime data untouched.
if [ -d runtime/view/compile ]; then
    find runtime/view/compile -type f -delete
fi
if [ -d runtime/view/cache ]; then
    find runtime/view/cache -type f -delete
fi

# 3.5.5 introduces persistent administrator sessions. The upstream release
# includes the table in Install.sql for fresh installs; create it idempotently
# for an existing Zeabur database before Apache starts.
if [ -f config/database.php ] && [ -f kernel/Install/Lock ]; then
    php -r '
        $cfg = require "config/database.php";
        $prefix = (string)($cfg["prefix"] ?? "");
        if (!preg_match("/^[A-Za-z0-9_]*$/", $prefix)) {
            throw new RuntimeException("Invalid database prefix");
        }
        $dsn = "mysql:host=" . $cfg["host"]
            . ";port=" . (int)($cfg["port"] ?? 3306)
            . ";dbname=" . $cfg["database"]
            . ";charset=" . ($cfg["charset"] ?? "utf8mb4");
        try {
            $pdo = new PDO($dsn, $cfg["username"], $cfg["password"], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            ]);
            $table = "`" . $prefix . "manage_session`";
            $manage = "`" . $prefix . "manage`";
            $constraint = "`" . $prefix . "manage_session_ibfk_1`";
            $pdo->exec("CREATE TABLE IF NOT EXISTS {$table} (
                `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
                `manage_id` int UNSIGNED NOT NULL,
                `session_hash` char(64) NOT NULL,
                `device_type` varchar(16) NOT NULL,
                `device_name` varchar(96) NOT NULL,
                `user_agent` varchar(512) NOT NULL,
                `login_ip` varchar(45) NOT NULL,
                `last_ip` varchar(45) NOT NULL,
                `created_time` datetime NOT NULL,
                `last_seen_time` datetime NOT NULL,
                `expires_time` datetime NOT NULL,
                `revoked_time` datetime NULL DEFAULT NULL,
                PRIMARY KEY (`id`),
                UNIQUE KEY `session_hash` (`session_hash`),
                KEY `manage_active` (`manage_id`, `revoked_time`, `expires_time`),
                KEY `last_seen_time` (`last_seen_time`),
                CONSTRAINT {$constraint} FOREIGN KEY (`manage_id`) REFERENCES {$manage} (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
            echo "[entrypoint] 3.5.5 database migration ready\n";
        } catch (Throwable $e) {
            fwrite(STDERR, "[entrypoint] 3.5.5 database migration failed: " . $e->getMessage() . "\n");
            exit(1);
        }
    '
fi

# 后台“基础设置”会把上传的 Logo 写到 /favicon.ico。
# 将它落到 assets/cache 这个持久化卷中，避免容器重建后丢失。
if [ ! -f assets/cache/favicon.ico ]; then
    if [ -f /usr/local/share/acg-faka/favicon.ico ]; then
        cp /usr/local/share/acg-faka/favicon.ico assets/cache/favicon.ico
    else
        : > assets/cache/favicon.ico
    fi
fi

if [ ! -L favicon.ico ]; then
    rm -f favicon.ico
    ln -s assets/cache/favicon.ico favicon.ico
fi

chown -R www-data:www-data \
    assets/cache \
    app/Pay \
    app/Plugin \
    app/View/User/Theme \
    config \
    kernel/Install \
    runtime

exec docker-php-entrypoint "$@"
