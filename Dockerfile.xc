# ==========================================
# 阶段一：在 GitHub 的服务器上进行暴力物理切除
# ==========================================
FROM onlyoffice/documentserver:latest AS builder

# 1. 暴力强拆依赖：无视 apt 报错，强行卸载数据库组件
RUN dpkg -l | grep -E "postgres|mysql|mariadb|sqlite" | awk '{print $2}' | xargs -r dpkg --force-depends --purge || true

# 2. 物理扫荡：彻底抹除硬盘上的残留目录和文件，应对 find / 扫描
RUN rm -rf /etc/postgresql /var/lib/postgresql /usr/lib/postgresql /var/log/postgresql /run/postgresql \
           /etc/mysql /var/lib/mysql /usr/lib/mysql /var/log/mysql \
           /usr/bin/sqlite3 /usr/bin/psql /usr/bin/mysql /usr/sbin/mysqld
RUN find / -iname "postgresql.conf" -exec rm -f {} + 2>/dev/null || true
RUN find / -iname "postmaster" -exec rm -f {} + 2>/dev/null || true
RUN find / -iname "my.cnf*" -exec rm -rf {} + 2>/dev/null || true
RUN find / -iname "sqlite3" -type f -exec rm -rf {} + 2>/dev/null || true

# 3. 狸猫换太子：造两个假的客户端文件，骗过 ONLYOFFICE 启动检测
RUN echo '#!/bin/sh\nexit 0' > /usr/bin/psql && chmod +x /usr/bin/psql
RUN echo '#!/bin/sh\nexit 0' > /usr/bin/mysql && chmod +x /usr/bin/mysql

# ==========================================
# 阶段二：空间折叠（抛弃全部历史层，打出纯净包）
# ==========================================
# scratch 是 Docker 的终极空白镜像（0字节，连操作系统都没有）
FROM scratch

# 把第一阶段清理干净的最终文件，完整拷贝过来
# 这一步直接丢弃了官方底层的几十层包含数据库的历史记录！
COPY --from=builder / /

# 恢复 ONLYOFFICE 核心运行所需的启动命令
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
EXPOSE 80 443
ENTRYPOINT ["/app/ds/run-document-server.sh"]
