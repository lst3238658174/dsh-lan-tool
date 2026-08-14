# dsh‑lan‑tool
DSH 局域网一体化工具，Windows批处理脚本，利用系统 `portproxy` 实现 DSH Web局域网访问。

> ⚠️安全警告：DSH存在远程代码执行风险，**仅限家庭内网使用，严禁暴露公网**。
> portproxy 是 Windows持久系统规则，重启电脑不会自动清除，使用完毕务必清理规则。

## 功能特性
- ✅管理员权限自动检测
- ✅自动探测本机局域网IP，单网卡环境无需手动配置IP
- ✅一键开启/关闭局域网端口转发(portproxy)
- ✅自动创建/清理 Windows防火墙放行规则
- ✅DSH程序状态检测
- ✅一键完整状态自检
- ✅一键拉起 DSH Web服务
- ✅退出前残留规则安全校验，防止遗忘清理持久转发
- ✅纯bat脚本，无需第三方依赖

## 环境要求
- Windows10 / Windows11
- DSH已npm全局安装，`dsh.cmd` 在 `%APPDATA%\npm\dsh.cmd`
- 端口转发、防火墙操作**需要管理员权限**

## 使用方法
1. 在Release下载 `dsh_tool.bat`
2. **右键 → 以管理员身份运行 dsh_tool.bat**

> 多网卡/VPN/WSL环境，如果自动识别IP错误，可以脚本顶部手动强制指定IP：
```batch
set LOCAL_IP=192.168.1.19
