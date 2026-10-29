# 轻绘 · SimplePaint

[English](README.md)

![用轻绘画一个安静的早晨](docs/screenshot-cn.jpg)

一款简单的画图程序，支持 macOS 和网页，灵感来自经典的 Windows 画图。

画几笔、写几个字、改张图片。都是熟悉的常规功能，所见即所得。

macOS 版打包仅 **2 MB**，支持 macOS 13 及以上版本。

## 工程目录

- `macos/`：macOS 原生应用、Xcode 工程、资源和构建脚本。
- `web/`：原生 HTML、CSS、JavaScript 网页版，无依赖、无构建步骤。
- `docs/`：两端共用的截图与文档资源。

### 网页版

在线使用：[轻绘网页版](https://jzlhll.github.io/MacSimplePaint/)。

在仓库根目录运行：

```bash
python3 -m http.server 8080 --directory web
```

使用现代浏览器打开 [http://localhost:8080](http://localhost:8080)，也可以部署到任意静态网站服务。图片完全在浏览器本地处理，保存时下载 PNG、JPEG 或 WebP 文件。访问系统剪贴板需要 HTTPS 或 localhost，并获得浏览器许可；页面内也保留独立剪贴板。

工作台布局最小为 **1200 × 800**，浏览器窗口更小时可滚动查看，不限制浏览器窗口大小。图片像素尺寸独立设置，默认 1200 × 800，可通过“尺寸”调整。状态栏位于“新建 / 打开 / 保存”下方，默认跟随浏览器深浅色，也可手动切换。

GitHub Pages 从 `gh-pages` 分支根目录发布。发布网页版时，为源码创建版本标签，再将 `web/` 内的静态文件发布到该分支；普通 `main` 分支推送不更新线上版本。

### macOS 开发

```bash
./macos/scripts/build.sh
./macos/scripts/run.sh
python3 macos/scripts/install_macos.py --skip-build
```

构建产物位于 `macos/build/SimplePaint.app`，本地签名配置位于 `macos/.local-signing.json`。

## 下载后无法打开

SimplePaint 目前使用自签名证书，尚未使用 Apple Developer ID 正式证书，因此 macOS 可能会阻止打开下载的应用。

确认下载来源可信，并将 SimplePaint 移动到 `/Applications` 后，在终端执行以下命令，移除应用的隔离属性，再重新打开：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/SimplePaint.app
```

按提示输入 Mac 登录密码即可，终端输入密码时不会显示字符。
