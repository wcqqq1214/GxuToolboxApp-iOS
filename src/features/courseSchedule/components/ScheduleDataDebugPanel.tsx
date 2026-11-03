import React, {useRef, useState} from "react";
import {ScrollView, View} from "react-native";
import {Button, Text, useTheme} from "@rneui/themed";
import {Flex, UnJsonEditor, UnTermSelector} from "@/components/un-ui";
import {useUserConfig} from "@/hooks/useUserConfig";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount";
import type {SchoolTermValue} from "@/type/global";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse";
import {scheduleCacheKey, type ScheduleScope} from "@/features/courseSchedule/repo/personalSchedule";
import {usePersonalCourseData} from "@/features/courseSchedule/hooks/detail/usePersonalCourseData.ts";
import {useScheduleCardData} from "@/features/courseSchedule/hooks/detail/useScheduleCardData.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";

interface RenderFrame {
    renderCount: number;
    inputYear: number;
    inputTerm: 1 | 2 | null;
    startYear: number;
    startTerm: number;
    ready: boolean;
    termReady: boolean;
    startDay: string;
}

/** 独立运行与首页相同的查询钩子，显式传入账号和学期。 */
export function ScheduleDataDebugPanel() {
    const {theme} = useTheme();
    const s = useStartDay();
    const [year, setYear] = useState(s.year);
    const [term, setTerm] = useState(s.term);
    const [showJson, setShowJson] = useState(false);
    const renderFrames = useRef<RenderFrame[]>([]);
    const {account, hydrating} = useJwAccount();
    const inputError = !Number.isInteger(year) || year <= 0 ? "请选择有效学年" : null;
    const scope: ScheduleScope | null =
        account?.username && !inputError ? {username: account.username, year, term} : null;

    const {schedule, status, error, refresh} = usePersonalCourseData(scope);

    const courseItems = schedule ? normalizeCourse(schedule) : [];

    const {courseItem, startYear, startTerm, ready, termReady, startDay} = useScheduleCardData(year, term);

    // 调试专用：在 render 当场保存值，不使用 setState，避免日志本身触发额外渲染。
    renderFrames.current.push({
        renderCount: renderFrames.current.length + 1,
        inputYear: year,
        inputTerm: term,
        startYear,
        startTerm,
        ready,
        termReady,
        startDay: startDay.format("YYYY-MM-DD"),
    });

    return (
        <ScrollView contentContainerStyle={{padding: 16, gap: 16}}>
            <Text h4>useScheduleData</Text>
            <Text>本页显式传入 scope，独立维护查询状态。输入相同值不会重新查询，手动刷新每次都会发出请求。</Text>
            <UnTermSelector
                year={year}
                term={term === 2 ? "12" : "3"}
                disableSelectAll
                onChange={(nextYear, nextTerm) => {
                    setYear(Number(nextYear));
                    setTerm(nextTerm === "12" || nextTerm === 12 ? 2 : 1);
                }}
            />
            <View style={{gap: 6}}>
                <Text style={{fontWeight: "700"}}>渲染帧日志（{renderFrames.current.length} 条）</Text>
                <Text style={{fontSize: 12, color: theme.colors.grey2}}>
                    每次组件 render 记录一条；红色表示 ready 为 true，但返回学期与输入不一致。切到 SQLite
                    标签再切回可重置日志。
                </Text>
                {renderFrames.current.map(frame => (
                    <Text
                        key={frame.renderCount}
                        selectable
                        style={{
                            fontSize: 12,
                            fontFamily: "monospace",
                            color:
                                frame.ready &&
                                (frame.inputYear !== frame.startYear || frame.inputTerm !== frame.startTerm)
                                    ? theme.colors.error
                                    : theme.colors.black,
                        }}>
                        {`#${frame.renderCount} input: ${frame.inputYear}-${frame.inputTerm ?? "?"} | hook返回: ${frame.startYear}-${frame.startTerm} | ready: ${frame.ready} | termReady: ${frame.termReady} | startDay: ${frame.startDay}`}
                    </Text>
                ))}
            </View>
            <View style={{gap: 8}}>
                <Text>账号：{scope?.username || (hydrating ? "读取中" : "未配置")}</Text>
                <Text>查询状态：{status}</Text>
                <Text>
                    理论课程：{schedule?.theoryList.length ?? 0}　实践课程：{schedule?.practiceList.length ?? 0}
                </Text>
                <Text>按周展开：{courseItems.length} 项</Text>
                <Text selectable>缓存键：{scope ? scheduleCacheKey(scope) : "无"}</Text>
            </View>
            {(error || inputError) && <Text style={{color: theme.colors.error}}>{error || inputError}</Text>}
            <Flex gap={8}>
                <Button disabled={!scope} loading={status === "loading"} onPress={refresh}>
                    刷新
                </Button>
                <Button
                    type="outline"
                    disabled={!scope}
                    onPress={async () => {
                        await Promise.all([refresh(), refresh(), refresh()]);
                    }}>
                    连续刷新 ×3
                </Button>
            </Flex>
            <Text>
                连续刷新会发出三次请求，只允许最后发起的一次更新数据、状态和缓存。旧请求失败也不能结束新请求的 loading。
            </Text>
            <Button type="outline" onPress={() => setShowJson(true)}>
                查看输入与课表数据
            </Button>
            <Text>
                验证建议：刷新中切换学期；切换账号后返回；断网刷新，检查已有数据是否保留。登录成功不会自动补查，可手动刷新。
            </Text>
            <Text>本页刷新不会同步首页的内存数据；目前只接入个人理论课和实践课。</Text>
            <UnJsonEditor.Modal readOnly visible={showJson} onClose={() => setShowJson(false)} value={{courseItem}} />
        </ScrollView>
    );
}
