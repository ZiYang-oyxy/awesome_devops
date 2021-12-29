# gdb-dashborad
https://github.com/cyrus-and/gdb-dashboard

## 补丁1
目前gdb常用的环境都是centos7，gdb版本7.6小于插件需要的8.0版本，语法高亮和一些插件有问题，参考`https://github.com/cyrus-and/gdb-dashboard/wiki/Support-older-GDB-versions`打了补丁，但是如果用高版本的话，可以去掉这些补丁

语法高亮还依赖pygments，具体使能方法参考`https://github.com/cyrus-and/gdb-dashboard/wiki/Choose-the-syntax-highlighting-style`，一般情况执行`yum install -y python-pygments`

## 补丁2
修改了.gdbinit的`clear_screen`函数，避免清空scrollback的缓存，导致无法看之前的调试历史
