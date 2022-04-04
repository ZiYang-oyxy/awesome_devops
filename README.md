# Awesome Devops说明书

⚙ Awesome Devops (or yet another AirDrop) ⚙

## 用途
文件中转；研发&运维工具箱

## 基本用法
```bash
# 安装
bash <(curl -s http://Awesome:Devops@<YOUR_HTTP_SERVER_IP>:8890/@aadi@) && source ~/.bashrc
# 升级
ad upgrade
# 查看help（此时会有版本检查，有新版本会提示升级）
ad
# 上传文件
ad put <file>
# 下载文件
ad get <file>
```
> 需要搭配[servefile](https://github.com/ZiYang-oyxy/servefile)使用

## FAQ
Q：Mac的同学用safari浏览器无法访问链接
A：换个浏览器试试，推荐用Chrome

Q：Mac的终端上安装后报错
A：ad大量使用bash脚本编写，不支持zsh，Mac上从默认的zsh切到bash方法：chsh -s /bin/bash。同时由于作者的mac上使用的都是gnu版本的工具，所以不保证mac原生工具没有兼容性问题

## 常用功能说明[WIP]
