# 运行环境
## 环境说明
本wiki只针对ubuntu(24.04 LTS)进行验证，其他系统请自行测试。
简单测试可以使用Docker进行镜像构建。
## openresty
- openresty: latest(current is 1.27.1.1)
参考[官方文档](https://openresty.org/cn/linux-packages.html#ubuntu)
```bash
# 导入官方GPG密钥
sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates lsb-release
wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
# 添加APT仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
# 安装openresty
sudo apt-get update
sudo apt-get -y install openresty
```
## 依赖
- 应用
```bash
sudo apt-get install luajit
sudo apt-get install liblua5.1-0-dev
# 用于组件安装
sudo apt-get install luarocks
```
- 组件
```bash
luarocks install lua-resty-jit-uuid
luarocks install lua-resty-redis
luarocks install lua-resty-http
luarocks install md5
luarocks install lua-ffi-zlib
luarocks install lua-resty-logger-socket
luarocks install net-url
opm get anjia0532/lua-resty-redis-util
```
# 部署
## 1.配置更新
|配置项|修改说明|
|------|------|
|redis|`conf/conf.lua`文件中 `_M.redis, _M.frequency_redis`，其中媒体广告位配置的地址要与Luna项目中配置的信息一致|
|上报服务域名|`conf/conf.lua`文件中`_M.track.url` 为Stella的服务域名|
| 密钥|`conf/conf.lua`文件中`_M.encryption_keys`，需与SDK侧的密钥一致 |
| 日志存储| `conf/conf.lua中的_M.log_type`。其中 `local`是本地存储模式，将会写文件到本地磁盘；`server`是发送到远端（比如`syslog-ng`），`conf/conf.lua`中`_M.center_syslog_ng`配置|
## 2.应用启停
```bash
# start
sh bin/start.sh
# stop
sh bin/stop.sh
# restart
sh bin/restart.sh 
```
## 3. IP解析(可选)
地域定向依赖 IP 解析。`GeoLite2-City.mmdb` 受 MaxMind 许可限制，不能随仓库分发，需自行下载后放到 `data/GeoLite2-City.mmdb`。未放置该文件时，已配置地域定向的广告源会被过滤掉。

- 第三方`maxmind`
```bash
# 安装maxmind的相关包
apt-get install libmaxminddb0 libmaxminddb-dev
# 安装openresty依赖组件
luarocks install lua-resty-maxminddb
```

1. 注册 [GeoLite 账号](https://www.maxmind.com/en/geolite2/signup)，并创建 [License Key](https://www.maxmind.com/en/accounts/current/manage/license-key)
2. 下载 **GeoLite2-City**（GZIP / MMDB）：[Download Databases](https://www.maxmind.com/en/accounts/current/geoip/downloads)，或：
```bash
curl -O -J -L -u YOUR_ACCOUNT_ID:YOUR_LICENSE_KEY \
  'https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz'
tar -xzf GeoLite2-City_*.tar.gz
```
3. 将解压出的 `GeoLite2-City.mmdb` 放到 `data/GeoLite2-City.mmdb`（相对项目根目录，即 `bin/start.sh` 的启动目录）

- 自定义IP解析
  
可修改`lua/processor/ip_region_analyzer.lua`文件替换为自己的IP解析，并根据自己的体系`id`与数据库中`system_code`表中`code_type_id=4`的地域信息进行`id`关系映射实现地域定向功能，映射功能和方法可参考现有使用了`maxmind`的映射关系代码。

## Docker
### 1. 配置更新
根据需要更新`Dockerfile`中的变量，参考上述配置更新
### 2. 构建镜像
```bash
sudo docker build -t Stella .
```
### 3. 运行容器
```bash
sudo docker run -dit --name Stella -p 80:80 Stella
```
若使用地域定向，需同时挂载数据库文件：
```bash
sudo docker run -dit --name Stella -p 80:80 \
  -v /path/to/GeoLite2-City.mmdb:/Stella/data/GeoLite2-City.mmdb:ro \
  Stella
```
