# first
#
#     docker build -t deployable/verdaccio .

# repeat
# 
#     docker build --build-arg DOCKER_BUILD_PROXY=http://10.8.8.8:3142 -t deployable/verdaccio . && docker stop sinopia && docker rm sinopia && docker run -v sinopia-storage:/sinopia/storage:rw -p 4873:4873 -d --name sinopia --restart always deployable/sinopia

FROM mhart/alpine-node:8.9.3 AS build

ARG DOCKER_BUILD_PROXY=''

COPY verdaccio-2.7.1/package.json verdaccio-2.7.1/yarn.lock /app/
RUN yarn install
COPY verdaccio-2.7.1 /app
RUN set -uex; \
    export http_proxy=${http_proxy:-${DOCKER_BUILD_PROXY}}; \
    apk update; \
    apk add g++ python-dev make; \
    export http_proxy=; \
    cd /app; \
    yarn install --pure-lockfile; \
    yarn cache clean; \
    rm -rf /usr/local/share/.cache/yarn; \
    apk del --purge python python-dev g++ musl-dev libc-dev gcc; \
    rm -rf /var/cache/apk;
RUN cd /app && yarn run build:webui

FROM mhart/alpine-node:8.9.3
WORKDIR /app
RUN set -uex; \
    adduser -D -g "" app; \
    adduser -D -g "" -G app appr; \
    mkdir -p /app/storage; \
    chown app /app/storage; \
    chmod 755 /app/storage;

COPY verdaccio-2.7.1/package.json verdaccio-2.7.1/yarn.lock /app/
RUN yarn install --production --pure-lockfile
COPY verdaccio-2.7.1 /app
COPY --from=build /app/static /app/static

# Use a custom verdaccio config
COPY /config.yaml /app/config.yaml

RUN set -uex; \
    touch /app/htpasswd; \
    chown -R app:app /app; \
    chown -R appr:app /app/storage; \
    chmod 755 /app/bin/verdaccio; \
    chown appr:app /app/htpasswd; \
    chmod 640 /app/htpasswd; \
    find /app -type d -exec chmod 755 {} +; \
    find /app -type f -exec chmod o+r {} +; \
    find /app -type f -exec chmod g+r {} +;

ADD /entrypoint.sh /docker-entrypoint.sh
USER appr
EXPOSE 4873
ENV PORT 4873
ENV PROTOCOL http
VOLUME ["/app/storage"]
#ENTRYPOINT ["/docker-entrypoint.sh"]
ENTRYPOINT []
CMD ["node", "--trace_gc", "/app/bin/verdaccio", "--config", "/app/config.yaml"]

