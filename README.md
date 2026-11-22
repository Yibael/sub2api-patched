# sub2api-patched

在官方 [sub2api](https://github.com/Wei-Shaw/sub2api) 的发布版上打几个还没被官方合并的补丁，构建 Docker 镜像推到 `ghcr.io/yibael/sub2api`。官方合并以后换回官方镜像，这个仓库就可以停用。

## 现在的补丁

| 补丁 | 作用 | 来源 |
| --- | --- | --- |
| `0001-forward-claude-code-agent-id-headers.patch` | 转发 Claude Code 子 agent 的 `x-claude-code-agent-id` / `x-claude-code-parent-agent-id` 请求头 | [Wei-Shaw/sub2api#7931](https://github.com/Wei-Shaw/sub2api/pull/7931)，作者 Cd1s |

为什么需要 0001：sub2api 只转发白名单（`backend/internal/service/gateway_service.go` 的 `allowedHeaders`）里的请求头，Claude Code 的头只放行了 `x-claude-code-session-id`。子 agent 的请求和主会话共用这个会话 ID，只能靠 agent ID 区分；ID 被丢掉后，下游的 CLIProxyAPI（以及 cred-guard 插件）把所有子 agent 都算进主会话，挤在同一个上游账号上。

## 怎么工作

`.github/workflows/build.yml` 每小时运行一次（也可以在 Actions 页面手动运行）：

1. 查官方最新 release 的版本号；`built-versions.txt` 里已经有的就跳过。
2. 拉官方这个版本的代码，用 `scripts/apply-patches.sh` 打上 `patches/` 里的补丁：
   - 能打上的就打上；
   - 官方代码里已经有了的就跳过（说明官方合并了）；
   - 两者都不是就失败，GitHub 会发邮件，需要手动更新补丁。
3. 把 `docker/append.Dockerfile` 接到官方根目录 `Dockerfile` 的末尾（装 curl，健康检查改成和官方镜像一样用 curl），构建并推送 `ghcr.io/yibael/sub2api:<版本号>`；是最新 release 时同时更新 `:latest`。
4. 把版本号写进 `built-versions.txt` 并提交。
5. 如果所有补丁官方都已经包含，开一个 issue 提醒换回官方镜像。

## 第一次使用

1. 在 GitHub 建仓库 `Yibael/sub2api-patched`，把这个目录推上去。
2. 在 Actions 页面手动运行一次 `build`（版本号留空），确认构建成功。
3. GHCR 上第一次推送的包默认是私有的。二选一：
   - 在包的设置里改成公开；
   - 或者在服务器上用一个只有 `read:packages` 权限的 token 执行 `docker login ghcr.io`。
4. 中转服务器的 `docker-compose.yml` 里把 `image: weishaw/sub2api:latest` 改成 `image: ghcr.io/yibael/sub2api:latest`，然后 `docker compose pull && docker compose up -d`。

## 日常

- 更新服务器和以前一样：`docker compose pull && docker compose up -d`，或者交给 Watchtower。
- 回退：把镜像标签换成上一个版本号，例如 `ghcr.io/yibael/sub2api:0.2.23`。
- 重新构建某个版本：手动运行 `build`，填版本号并勾选 force。
- 加补丁：把 `git format-patch` 格式的补丁放进 `patches/`，按文件名顺序应用。本地先用 `scripts/apply-patches.sh <sub2api 目录>` 试一下。

## 注意

- 公开仓库 60 天没有提交时，GitHub 会停掉定时任务。每次构建都会提交 `built-versions.txt`，官方一直在发版就不会停；停了的话在 Actions 页面重新启用。
- 默认只构建 `linux/amd64`。服务器是 ARM 的话，把 workflow 里的 `PLATFORMS` 改成 `linux/amd64,linux/arm64`（arm64 的最后一步在 QEMU 里跑，会慢一些）。
- 官方发布的镜像是用预先编译好的二进制打包的（`Dockerfile.goreleaser`）；这里用根目录的 `Dockerfile` 从源码构建，再补上 curl。剩下的一处不同是 `/app` 目录属于 root（官方属于 sub2api 用户）。
- **不要用 sub2api 管理后台的「在线更新」。** 它会把官方程序写进 `/app` 替换掉打了补丁的程序；这里 `/app` 属于 root，在线更新会失败，正好避免补丁被悄悄丢掉。更新一律走拉新镜像。
- sub2api 使用 LGPL-3.0 许可证。镜像公开时需要同时公开修改过的源码，这个仓库里的补丁就是全部修改。
