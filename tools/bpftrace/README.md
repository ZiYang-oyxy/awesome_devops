# 快速上手
[深入浅出 eBPF 技术](https://developer.aliyun.com/article/1223770)
[bpftrace原理](https://github.com/iovisor/bpftrace/blob/master/docs/internals_development.md)
[bpftrace一行教程](https://github.com/iovisor/bpftrace/blob/master/docs/tutorial_one_liners_chinese.md)

# 一键安装
```bash
ad upgrade # 更新到最新版本
ad deploy bpftrace # x86平台
```
> 也能直接从源装，但是享受不了最新版的各种特性，而且依赖比较多，我是直接用源码编译的x86版本，自包含，开箱即用

# 使用
```
source  ~/.bashrc # 第一次安装后需要执行

# 使用这个示例脚本，分析iperf3进程的tcp收发统计
ad bpftrace tcp_profile.bt `pidof iperf3` 

# 获得所有示例脚本路径，查看并参考实现自己的脚本
ad bpftrace 
```

# 添加trace点
有些场景下需要分析的地方没有找到可trace的点，只能自己加函数，则一定要注意**显式地**给函数添加去优化的声明，否则可能会被优化而无法被trace
```c
void __attribute__((optimize("O0"))) my_function() {

    // 函数实现

}
```

# 附
## 编译静态链接版bpftrace

```bash
git clone https://github.com/iovisor/bpftrace.git
cd bpftrace
cp docker/Dockerfile.static Dockerfile

yum install -y \
    asciidoctor \
    bison \
    binutils-devel \
    bcc-devel \
    cereal-devel \
    clang-devel \
    cmake \
    elfutils-libelf-devel \
    elfutils-libs \
    flex \
    libpcap-devel \
    libbpf-devel \
    llvm-devel \
    systemtap-sdt-devel \
    zlib-devel zlib-static

cat << EOF >> Dockerfile

COPY . /src
WORKDIR /src
RUN cmake -B /build -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=MinSizeRel
RUN make -C /build -j$(nproc)

ENTRYPOINT ["/build/src/bpftrace"]
EOF

docker build -t bpftrace_build .
docker create --name bpftrace_build-container bpftrace_build
docker cp bpftrace_build-container:/build/src/bpftrace .
strip ./bpftrace
```

静态版本会依赖musl c库，对应不同的linux发行版，需要安装对应的musl c库

## 重新编译内核，添加ebpf需要的debug信息
1. **编译内核时生成Debug信息**：
在编译内核时，确保开启了生成调试信息的选项。这通常涉及到在`make menuconfig`配置界面中启用相关选项（例如，“Kernel hacking” -> “Compile-time checks and compiler options” -> “Compile the kernel with debug info”）。这会使得编译出来的vmlinux文件包含调试信息。

2. **安装Headers**：
内核headers通常在编译过程中被创建，并且可以直接被安装。执行以下命令：
```bash
make headers_install INSTALL_HDR_PATH=/usr/src/kernels/$(make kernelrelease)
```
这将会把headers复制到`/usr/src/kernels/<kernel-version>/`目录下。

##  BPF CO-RE (Compile Once – Run Everywhere)[](https://libbpf.readthedocs.io/en/latest/libbpf_overview.html?spm=a2c6h.12873639.article-detail.12.133d5c69AN7mlU#bpf-co-re-compile-once-run-everywhere "Link to this heading")
让bpf脚本include这个`vmlinux.h`文件，就能包含内核所有头文件的定义
```
$ bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
```

## 找不到头文件的时候
用-I参数，例如
```
$ bpftrace -I /usr/src/kernels/4.18.0-348.7.1.el8_5.x86_64/include ./x.bt
```
