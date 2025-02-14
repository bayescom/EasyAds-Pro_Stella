FROM openresty/openresty:jammy 

ENV DEBIAN_FRONTEND=noninteractive
# install deps 
ARG BUILD_TEMP="git"
ARG BUILD_DEPS="luajit liblua5.1-0-dev libmaxminddb0 libmaxminddb-dev"

RUN set -ex \
    && apt-get update \
    && apt-get install -y ${BUILD_DEPS} ${BUILD_TEMP} --no-install-recommends 
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-jit-uuid \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-redis \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-http \
    && /usr/local/openresty/luajit/bin/luarocks install md5 \
    && /usr/local/openresty/luajit/bin/luarocks install lua-ffi-zlib \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-logger-socket \
    && /usr/local/openresty/luajit/bin/luarocks install net-url \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-maxminddb \  
    && /usr/local/openresty/bin/opm get anjia0532/lua-resty-redis-util \
    && apt-get remove -y ${BUILD_TEMP}
# timezone
RUN rm -f /etc/localtime \
    && ln -sv /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

COPY . /Stella
WORKDIR /Stella

ENV DOMAIN_STELLA=your.domain
ENV SECRET_KEY=yoursecretkey
ENV LOG_TYPE=local
ENV LOG_URL=127.0.0.1
ENV LOG_PORT=12001
ENV REDIS_URL=127.0.0.1
ENV REDIS_PORT=6379
ENV REDIS_PASSWORD=yourpasswd

RUN sed -i 's/${DOMAIN_STELLA}/'$DOMAIN_STELLA'/g' ./conf/conf.lua \
   && sed -i 's/${SECRET_KEY}/'$SECRET_KEY'/g' ./conf/conf.lua \
   && sed -i 's/${LOG_TYPE}/'$LOG_TYPE'/g' ./conf/conf.lua \
   && sed -i 's/${LOG_URL}/'$LOG_URL'/g' ./conf/conf.lua \
   && sed -i 's/${LOG_PORT}/'$LOG_PORT'/g' ./conf/conf.lua \
   && sed -i 's/${REDIS_URL}/'$REDIS_URL'/g' ./conf/conf.lua \
   && sed -i 's/${REDIS_PORT}/'$REDIS_PORT'/g' ./conf/conf.lua \
   && sed -i 's/${REDIS_PASSWORD}/'$REDIS_PASSWORD'/g' ./conf/conf.lua
    
EXPOSE 80
CMD ["/usr/local/openresty/bin/openresty", "-p", ".", "-c", "./conf/nginx.conf","-g", "daemon off;"]
