import {memo, useMemo} from "react";
import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {useShallow} from "zustand/react/shallow";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {Color} from "@/shared/color.ts";
import {UnText} from "@/components/un-ui";
import type {FreeRunItem} from "../type";

export type EmptyRunBlockProps = {
    item: FreeRunItem;
};

/**
 * 作用：在 TimeSchedule 的日期列中渲染一段连续空闲时间。
 * 入参：item（week/day/begin/end，1-based）。
 * 修改注意：
 * - 绝对定位数学与 NewCourseItem 一致：top=(begin-1)*timeSpanHeight+margin，
 *   height=(end-begin+1)*timeSpanHeight-2*margin；压缩模式需补足奇数末尾节的成对高度；
 * - 不要加 weekdayHeight：renderItems 的零高度 wrapper 已经位于星期表头下方。
 */
export const EmptyRunBlock = memo(function EmptyRunBlock({item}: EmptyRunBlockProps) {
    const {store} = useCourseData();
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const courseItemMargin = store(s => s.theme.courseItemMargin);
    const timeSpanList = store(s => s.timeSpanList);
    const theme = useTheme().theme;

    const span = item.end - item.begin + 1;
    const needsTrailingSlot = timeSpanHeight <= 40 && timeSpanList.length % 2 === 1 && item.end === timeSpanList.length;
    const displaySpan = span + (needsTrailingSlot ? 1 : 0);
    const top = (item.begin - 1) * timeSpanHeight + courseItemMargin;
    const height = displaySpan * timeSpanHeight - courseItemMargin * 2;
    const backgroundColor = Color(theme.colors.success).setAlpha(theme.mode === "light" ? 0.2 : 0.1).rgbaString;
    const borderColor = Color(theme.colors.success).setAlpha(theme.mode === "light" ? 0.65 : 0.5).rgbaString;
    const textColor = Color.mix(theme.colors.success, theme.colors.black, 0.45).rgbaString;

    const styles = useMemo(
        () =>
            StyleSheet.create({
                container: {
                    position: "absolute",
                    width: "96%",
                    marginHorizontal: "2%",
                    top,
                    height,
                    borderRadius: 5,
                    borderWidth: 1,
                    borderColor,
                    backgroundColor,
                    alignItems: "center",
                    justifyContent: "center",
                    overflow: "hidden",
                },
                content: {
                    alignItems: "center",
                    gap: 2,
                    width: "100%",
                },
                text: {
                    fontSize: 10,
                    fontWeight: "bold",
                    color: textColor,
                    textAlign: "center",
                    lineHeight: 12,
                    paddingHorizontal: 2,
                    width: "100%",
                },
            }),
        [top, height, backgroundColor, borderColor, textColor, store(useShallow(s => s.theme))],
    );

    return (
        <View style={styles.container} pointerEvents="none">
            <View style={styles.content}>
                <UnText style={styles.text}>{span === 1 ? "空闲" : `空闲 ${span} 节`}</UnText>
                <UnText style={styles.text}>{`第${item.begin}节\n至\n第${item.end}节`}</UnText>
            </View>
        </View>
    );
});
