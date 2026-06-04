#!/usr/bin/env bash
set -euo pipefail

if ! schematool -dbType postgres -info >/tmp/hive-schematool-info.log 2>&1; then
  schematool -dbType postgres -initSchema
fi

exec /opt/hive/bin/hive --service metastore
