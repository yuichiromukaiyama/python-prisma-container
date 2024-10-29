FROM python:3.11-slim-bookworm AS development

ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:0.4.3 /uv /bin/uv

COPY pyproject.toml /app/pyproject.toml
COPY uv.lock /app/uv.lock
COPY prisma/schema.prisma /app/prisma/schema.prisma
COPY prisma/migrations/ /app/prisma/migrations/
COPY main.py /app/main.py
COPY entrypoint.py /app/entrypoint.py

RUN \
  apt-get update && \ 
  apt-get install -y openssl 

RUN \
  uv sync --no-dev --no-cache --frozen  && \
  uv run prisma py generate

FROM busybox:uclibc AS libc-build
FROM gcr.io/distroless/python3-debian12:nonroot

ENV \
  PYTHONUNBUFFERED=1 \
  PYTHONPATH=/usr/local/lib/python3.11/site-packages \
  TZ=Asia/Tokyo \
  LANG=ja_JP.UTF-8 \
  LC_ALL=ja_JP.UTF-8

WORKDIR /app

# debug で shell を使いたい時は有効にする
# COPY --from=libc-build --chown=nonroot:nonroot /bin/sh /bin/sh
# COPY --from=libc-build --chown=nonroot:nonroot /bin/ls /bin/ls

# 依存関係 cat の追加 -- prisma connect 時に必要となるため
COPY --from=libc-build --chown=nonroot:nonroot /bin/cat /bin/cat

# 依存関係: openssl の追加 -- prisma で使用するため -- openssl の依存関係は ldd /usr/bin/openssl で確認
COPY --from=development --chown=nonroot:nonroot /usr/bin/openssl /usr/bin/openssl
COPY --from=development --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libssl.so.3 /lib/libssl.so.3
COPY --from=development --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/libcrypto.so.3
COPY --from=development --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libc.so.6 /lib/libc.so.6
COPY --from=development --chown=nonroot:nonroot /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# 依存関係: アプリの追加 -- prisma 関連バイナリーもコピーする
COPY --from=development --chown=nonroot:nonroot /app/.venv/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=development --chown=nonroot:nonroot /app/.venv/bin/prisma-client-py /usr/local/bin/prisma-client-py
COPY --from=development --chown=nonroot:nonroot /app/.venv/bin/prisma /usr/local/bin/prisma
COPY --from=development --chown=nonroot:nonroot /app/.binaries/ /app/.binaries/
COPY --from=development --chown=nonroot:nonroot /app/main.py /app/main.py
COPY --from=development --chown=nonroot:nonroot /app/entrypoint.py /app/entrypoint.py
COPY --from=development --chown=nonroot:nonroot /app/prisma/schema.prisma /app/prisma/schema.prisma
COPY --from=development --chown=nonroot:nonroot /app/prisma/migrations/ /app/prisma/migrations/
COPY --from=development --chown=nonroot:nonroot /app/pyproject.toml /app/pyproject.toml

USER nonroot

EXPOSE 8000

CMD ["/app/entrypoint.py"]