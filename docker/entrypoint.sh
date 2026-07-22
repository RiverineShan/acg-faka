#!/bin/bash
set -e

# --- ensure core directories exist ---
mkdir -p /var/www/html/config
mkdir -p /var/www/html/kernel/Install
mkdir -p /var/www/html/assets/cache
mkdir -p /var/www/html/runtime

# Compiled views contain generated PHP from the application version that
# created them. The runtime directory may be backed by a persistent volume on
# Zeabur, so discard only these rebuildable files on every deployment to avoid
# mixing old templates with the newly deployed controllers.
if [ -d /var/www/html/runtime/view/compile ]; then
  find /var/www/html/runtime/view/compile -type f -delete
fi

# Zeabur may mount app/View/User/Theme as a persistent volume. Refresh the
# bundled theme files from the newly built image so an older deployment cannot
# keep serving legacy templates. Extra user-installed theme directories remain
# untouched.
if [ -d /usr/local/share/acg-faka/default-theme ]; then
  cp -a /usr/local/share/acg-faka/default-theme/. /var/www/html/app/View/User/Theme/
fi

# --- default config placeholders (only if file missing) ---
if [ ! -f /var/www/html/config/app.php ]; then
  cat > /var/www/html/config/app.php << 'APPCFG'
<?php
return [
    'version' => '3.1.9',
    'debug' => false,
];
APPCFG
fi

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

if [ ! -f /var/www/html/config/dependencies.php ]; then
  cat > /var/www/html/config/dependencies.php << 'DEPCFG'
<?php
return [];
DEPCFG
fi

# --- database config: persist from volume, fallback to env ---
if [ ! -f /var/www/html/config/database.php ]; then
  DB_HOST="${DB_HOST:-mysql}"
  DB_NAME="${DB_NAME:-zeabur}"
  DB_USER="${DB_USER:-acgapp}"
  DB_PASS="${DB_PASS:-}"
  DB_PREFIX="${DB_PREFIX:-acg_}"
  cat > /var/www/html/config/database.php << DBCFG
<?php
return [
    'driver' => 'mysql',
    'host' => '${DB_HOST}',
    'database' => '${DB_NAME}',
    'username' => '${DB_USER}',
    'password' => '${DB_PASS}',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_general_ci',
    'prefix' => '${DB_PREFIX}',
];
DBCFG
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
        'mysql:host='.\$cfg['host'].';dbname='.\$cfg['database'],
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
