#!/bin/bash
set -e

# --- ensure persistent directories exist and seed missing application files ---
mkdir -p \
  /var/www/html/config \
  /var/www/html/kernel/Install \
  /var/www/html/assets/cache \
  /var/www/html/runtime \
  /var/www/html/app/Plugin \
  /var/www/html/app/Pay \
  /var/www/html/app/View/User/Theme

# Persistent volumes hide files baked into the image. Fill only missing files so
# upgrades add defaults without overwriting installed configuration or plugins.
cp -a -n /opt/acg-defaults/config/. /var/www/html/config/
cp -a -n /opt/acg-defaults/install/. /var/www/html/kernel/Install/
cp -a -n /opt/acg-defaults/plugins/. /var/www/html/app/Plugin/
cp -a -n /opt/acg-defaults/pay/. /var/www/html/app/Pay/
cp -a -n /opt/acg-defaults/themes/. /var/www/html/app/View/User/Theme/

# Core files must match the deployed application version. Persistent volumes may
# still contain files from a newer release, so refresh only framework-owned
# defaults while preserving database.php, plugins, payments and custom themes.
cp -a /opt/acg-defaults/config/app.php /var/www/html/config/app.php
if [ -d /opt/acg-defaults/config/waf ]; then
  mkdir -p /var/www/html/config/waf
  cp -a /opt/acg-defaults/config/waf/. /var/www/html/config/waf/
fi
if [ -d /opt/acg-defaults/themes/Cartoon ]; then
  mkdir -p /var/www/html/app/View/User/Theme/Cartoon
  cp -a /opt/acg-defaults/themes/Cartoon/. /var/www/html/app/View/User/Theme/Cartoon/
fi

# Compiled templates from another version are not reusable.
rm -rf /var/www/html/runtime/view/compile/* /var/www/html/runtime/view/cache/*

if [ ! -f /var/www/html/config/store.php ]; then
  cat > /var/www/html/config/store.php << 'STORECFG'
<?php
return [
    'app_id' => '',
    'app_key' => '',
    'server' => 0,
];
STORECFG
fi

# --- database config: persist from volume, fallback to env ---
if [ ! -f /var/www/html/config/database.php ]; then
  export DB_HOST="${DB_HOST:-mysql}"
  export DB_PORT="${DB_PORT:-3306}"
  export DB_NAME="${DB_NAME:-zeabur}"
  export DB_USER="${DB_USER:-acgapp}"
  export DB_PASS="${DB_PASS:-${DB_PASSWORD:-}}"
  export DB_PREFIX="${DB_PREFIX:-acg_}"
  php -r '
    $config = [
      "driver" => "mysql",
      "host" => getenv("DB_HOST"),
      "port" => (int)getenv("DB_PORT"),
      "database" => getenv("DB_NAME"),
      "username" => getenv("DB_USER"),
      "password" => getenv("DB_PASS"),
      "charset" => "utf8mb4",
      "collation" => "utf8mb4_general_ci",
      "prefix" => getenv("DB_PREFIX"),
    ];
    file_put_contents(
      "/var/www/html/config/database.php",
      "<?php\ndeclare(strict_types=1);\n\nreturn " . var_export($config, true) . ";\n"
    );
  '
  echo "[entrypoint] database.php created"
else
  echo "[entrypoint] database.php already exists, skip"
fi

# --- ensure Lock file for post-install state ---
if [ ! -f /var/www/html/kernel/Install/Lock ]; then
  # check if DB has tables (meaning installed)
  php -r "
    \$cfg = require '/var/www/html/config/database.php';
    try {
      \$pdo = new PDO(
        'mysql:host='.\$cfg['host'].';port='.(\$cfg['port'] ?? 3306).';dbname='.\$cfg['database'],
        \$cfg['username'], \$cfg['password']
      );
      \$tables = \$pdo->query('SHOW TABLES')->fetchAll();
      if (count(\$tables) > 0) {
        file_put_contents('/var/www/html/kernel/Install/Lock', (string)time());
        echo 'Lock created (DB has tables)' . PHP_EOL;
      } else {
        echo 'DB empty, no Lock created' . PHP_EOL;
      }
    } catch (Exception \$e) {
      echo 'Cannot connect to DB: ' . \$e->getMessage() . PHP_EOL;
    }
  "
fi

# --- composer install if needed ---
if [ ! -d /var/www/html/vendor ] || [ ! -f /var/www/html/vendor/autoload.php ]; then
  composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction
else
  composer dump-autoload --optimize --no-interaction
fi

chown -R www-data:www-data /var/www/html
chmod -R ug+rwX /var/www/html

exec "$@"
