# 使用基础镜像
FROM registry.cn-beijing.aliyuncs.com/lixxcn/ubuntu:24.04

# 设置环境变量，避免安装过程中的交互
ENV DEBIAN_FRONTEND=noninteractive

# 更新并安装 FFmpeg 和 Nginx
RUN sed -i 's@//ports.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y ffmpeg nginx && \
    apt-get clean

# 创建目录存储 HLS 输出
RUN mkdir -p /var/www/hls

# 复制 Nginx 配置文件
COPY nginx.conf /etc/nginx/nginx.conf

# 复制 HTML 页面
COPY index.html /var/www/html/index.html

# 复制启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 设置工作目录
WORKDIR /var/www/hls

# 暴露端口
EXPOSE 80

# 启动容器时运行的命令
CMD ["/start.sh"]