# Debug Session: zeabur-404-page
- **Status**: [OPEN]
- **Issue**: Zeabur 部署后首页与后台均返回项目自带 404 页面
- **Debug Server**: N/A
- **Log File**: N/A

## Reproduction Steps
1. 在 Zeabur 部署 `acg-faka-app`
2. 绑定 `ycloudshop-acg.zeabur.app`
3. 访问 `/` 或 `/admin`
4. 页面显示项目自带 404 页

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | 安装后数据库配置未正确落盘或被覆盖，导致运行时异常统一渲染为 404 | High | Med | Pending |
| B | Zeabur 持久化卷覆盖了默认配置/主题/安装资源，导致首页与后台模板加载失败 | High | Med | Pending |
| C | Zeabur 运行时服务内网连接与安装页填写不一致，导致应用实际连不到 MySQL | Med | Med | Pending |
| D | 当前 404 来自运行期异常，而非后台安全入口或域名配置问题 | High | Low | Pending |
| E | 需要直接查看 Zeabur 运行日志才能确认真实异常栈 | High | Low | Pending |

## Log Evidence
- 待收集 Zeabur `acg-faka-app` 运行日志

## Verification Conclusion
- 待确认
