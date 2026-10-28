# 本地开发流程

- 本程序自测已获用户授权，可直接启动开发或隔离副本，执行绘制、打开、保存、改名等验证操作，并关闭、丢弃自测产生的文档，无需重复请示；保留用户原有文档与未保存内容。
- 修改后按需使用 `./scripts/build.sh` 编译，沿用现有固定自签名证书。
- 自测使用构建目录中的 `build/SimplePaint.app`；每次修改并编译成功后，默认同步替换 `/Applications/SimplePaint.app`，无需再次请示。
- 构建并安装使用 `python3 scripts/install_macos.py`；已有最新构建时使用 `python3 scripts/install_macos.py --skip-build`。替换前正常退出安装版，保留用户文档与未保存内容；遇到保存提示时等待用户处理，禁止强制结束进程或丢弃用户内容。
- 构建产物必须先在临时目录完整打包签名，再整包切换；旧包保留于 `.build/retired-apps`，禁止原地覆盖运行中的二进制或重签正在运行的应用。
