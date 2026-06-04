FROM bde2020/hive:2.3.2-postgresql-metastore

USER root

RUN if ! getent group supergroup >/dev/null; then \
      printf 'supergroup:x:1001:\n' >> /etc/group; \
    fi && \
    if ! getent passwd hive >/dev/null; then \
      printf 'hive:x:1002:1001:Hive User:/opt/hive:/bin/bash\n' >> /etc/passwd; \
    fi
