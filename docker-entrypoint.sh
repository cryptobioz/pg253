#!/bin/bash

pg_dump -Fc | aws s3 cp - "s3://${AWS_S3_BUCKET}/postgres.${PGDATABASE}.$(date +%Y%m%d-%H%M).dump"

pg_dump_status=${PIPESTATUS[0]}
echo "pg_dump exited with status: ${pg_dump_status}"

aws_status=${PIPESTATUS[1]}
echo "aws exited with status: ${aws_status}"

stats=$(aws s3 ls --summarize --recursive "${AWS_S3_BUCKET}")
objects=$(sed -n '/ *Total Objects: / s///p' <<<"${stats}")
echo "Total Objects in bucket: ${objects}"

size=$(sed -n '/ *Total Size: / s///p' <<<"${stats}")
echo "Total Size of bucket: ${size}"

if [ ! -z "${PROMETHEUS_PUSHGATEWAY}" ]; then
  cat <<EOF | curl --data-binary @- "${PROMETHEUS_PUSHGATEWAY}/metrics/postgres_s3_backup/${PG_DATABASE}"
# TYPE pg_dump_status counter
pg_dump_status ${pg_dump_status}
# TYPE aws_status counter
aws_status ${aws_status}
# TYPE objects counter
objects ${objects}
# TYPE size counter
size ${size}
EOF
fi
