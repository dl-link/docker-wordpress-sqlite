ARG TAG=apache
FROM wordpress:${TAG}

# Configurable environment variables (with default values)
ENV PHP_UPLOAD_MAX_FILESIZE=36M \
    PHP_POST_MAX_SIZE=36M \
    PHP_MAX_EXECUTION_TIME=150 \
    PHP_MEMORY_LIMIT=256M \
    PHP_MAX_INPUT_TIME=120 \
    WORDPRESS_SOURCE_DIR="/usr/src/wordpress" \
    WORDPRESS_TARGET_DIR="/var/www/html"

# Dynamically generate PHP configuration (using environment variables)
RUN { \
    echo "upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}"; \
    echo "post_max_size = ${PHP_POST_MAX_SIZE}"; \
    echo "max_execution_time = ${PHP_MAX_EXECUTION_TIME}"; \
    echo "memory_limit = ${PHP_MEMORY_LIMIT}"; \
    echo "max_input_time = ${PHP_MAX_INPUT_TIME}"; \
    echo "file_uploads = On"; \
    echo "max_file_uploads = 20"; \
} > /usr/local/etc/php/conf.d/custom-uploads.ini && \
    # Syntax Check
    php -i > /dev/null

# Install SQLite plugin (retains original logic)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN export SQLITE_PLUGIN_VERSION=$(curl -sI "https://github.com/WordPress/sqlite-database-integration/releases/latest" | grep -i location | awk -F'/' '{print $NF}' | tr -d '\r') && \
    mkdir -p ${WORDPRESS_SOURCE_DIR}/wp-content/mu-plugins/sqlite-database-integration && \
    curl -L "https://github.com/WordPress/sqlite-database-integration/archive/refs/tags/${SQLITE_PLUGIN_VERSION}.tar.gz" | \
    tar xz --strip-components=1 -C ${WORDPRESS_SOURCE_DIR}/wp-content/mu-plugins/sqlite-database-integration

# Configure SQLite plugin
RUN mv "${WORDPRESS_SOURCE_DIR}/wp-content/mu-plugins/sqlite-database-integration/db.copy" "${WORDPRESS_SOURCE_DIR}/wp-content/db.php" && \
    sed -i "s#{SQLITE_IMPLEMENTATION_FOLDER_PATH}#${WORDPRESS_TARGET_DIR}/wp-content/mu-plugins/sqlite-database-integration#" "${WORDPRESS_SOURCE_DIR}/wp-content/db.php" && \
    sed -i "s#{SQLITE_PLUGIN}#${WORDPRESS_TARGET_DIR}/wp-content/mu-plugins/sqlite-database-integration/load.php#" "${WORDPRESS_SOURCE_DIR}/wp-content/db.php" && \
    # 权限设置
    chown -R www-data:www-data ${WORDPRESS_SOURCE_DIR}/wp-content && \
    chmod -R 755 ${WORDPRESS_SOURCE_DIR}/wp-content

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1
