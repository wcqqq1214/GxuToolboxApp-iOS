# 校选课查漏

正式入口 `screen/ElectiveStrategy.tsx` 转到 `ElectiveProgressScreen`，通过 `useElectiveProgress` 请求 `GET /jw/elective-progress`。页面直接展示后端返回的课程、学分、要求及达标状态，只格式化数值，不做课程去重、成绩匹配或规则判断。

接口响应在 `schema/progress.ts` 校验，年级由后端决定；聚合请求使用 30 秒超时。完整服务端结果通过 `ElectiveProgressRepo` 缓存在 MMKV，按当前教务账号隔离。刷新失败保留上次结果和更新时间，账号切换及新刷新会使旧请求失效，旧请求不能写页面或缓存。

`complete=false` 或 `isQualified=null` 显示待核对，不当作未达标。每门课程使用后端 `status`、`counted` 及 `excludedReason` 显示状态。

旧页面完整保留在 `screen/LegacyElectiveStrategy.tsx`，其 `useElectiveStrategyData`、年级策略和旧类型均暂留，等待与真实教务数据对照验证后再决定是否删除。当前路由不会自动回退到旧页面或旧算法。
