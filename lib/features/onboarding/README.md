# feature/onboarding

- 原 Kotlin 模块：apps/android .../feature/onboarding
- 设计文档：docs/design/02-onboarding-auth.md
- 状态：✅ 已实现（probeHealth → checkBootstrap → POST /api/v1/auth/device/login → session.login；登录页 OnboardingPage 深色渐变 + 服务器地址输入 + done→跳转）
- 页面：pages/onboarding_page.dart；状态：state/onboarding_controller.dart（OnboardingState/OnboardingController/onboardingProvider）
- 约束：禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
- M6 多设备：登录内容居中限宽（compact<=560，其余 720），连接按钮包 McFocusRing。
