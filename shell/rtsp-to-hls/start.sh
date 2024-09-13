#!/bin/bash

# 启动 Nginx
nginx

# 使用 FFmpeg 将 RTSP 流转换为 HLS 并输出到 /var/www/hls
# 增加分析时间：你可以增加 analyzeduration 和 probesize 的值，让 FFmpeg 有更多时间去分析流媒体，识别出视频参数。
# 这个命令使用 FFmpeg 从指定的 RTSP 摄像头流中拉取视频，通过 TCP 协议传输，分析和探测较大的数据，保持视频和音频的原始编码格式（不重新编码），并将视频转换为 HLS（HTTP Live Streaming）格式，生成 .m3u8 索引文件和 .ts 分片文件，以便在网页上通过 HLS 播放摄像头的实时视频流。
ffmpeg -rtsp_transport tcp -analyzeduration 10000000 -probesize 10000000 -i rtsp://admin:fy123456@172.16.12.203:554/Streaming/Channels/101 -c:v copy -c:a copy -hls_time 2 -hls_list_size 1800 -f hls /var/www/hls/output.m3u8

# 保持容器运行
tail -f /dev/null