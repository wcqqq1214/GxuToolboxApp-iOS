import React, {useMemo} from "react";
import {StyleSheet, View} from "react-native";
import {Divider, Image, useTheme} from "@rneui/themed";
import {UnText} from "@/components/un-ui";
import {Color} from "@/shared/color.ts";
import {TeacherInfoDetail} from "@gxutool/adapters/teacherInfo";
import dayjs from "dayjs";

const DEFAULT_PHOTO = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

/**
 * 展示教师头像和基础资料，作为详情 SectionList 的列表头部。
 */
export function DetailHeader({info}: {info: TeacherInfoDetail}) {
    const {theme} = useTheme();
    const styles = useMemo(
        () =>
            StyleSheet.create({
                container: {
                    paddingHorizontal: 12,
                    paddingVertical: 10,
                },
                row: {
                    flexDirection: "row",
                    alignItems: "flex-start",
                    gap: 14,
                },
                photo: {
                    width: 110,
                    height: 150,
                    borderRadius: 4,
                },
                details: {
                    flex: 1,
                    gap: 6,
                    paddingTop: 2,
                },
                nameRow: {
                    flexDirection: "row",
                    alignItems: "center",
                    flexWrap: "wrap",
                    gap: 6,
                },
                name: {
                    flexShrink: 1,
                    fontWeight: "bold",
                    color: theme.colors.primary,
                },
                badge: {
                    backgroundColor: Color(theme.colors.primary).setAlpha(0.3).rgbaString,
                    paddingHorizontal: 4,
                    paddingVertical: 2,
                    borderRadius: 4,
                },
                line: {
                    flexDirection: "row",
                    flexWrap: "wrap",
                    gap: 4,
                },
                label: {
                    flexShrink: 0,
                },
                value: {
                    flexShrink: 1,
                },
            }),
        [theme],
    );
    const badgeColor = Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString;

    return (
        <View style={styles.container}>
            <View style={styles.row}>
                <Image source={{uri: info.baseInfo.pic || DEFAULT_PHOTO}} style={styles.photo} />
                <View style={styles.details}>
                    <View style={styles.nameRow}>
                        <UnText size={20} style={styles.name}>
                            {info.baseInfo.name || "未知姓名"}
                        </UnText>
                        <UnText size={14} style={styles.badge} color={badgeColor}>
                            {info.baseInfo.title || "无职称信息"}
                        </UnText>
                        <UnText size={14} style={styles.badge} color={badgeColor}>
                            {info.academicProfile.employeeNumber || "工号未知"}
                        </UnText>
                    </View>
                    <View style={styles.line}>
                        <UnText size={14}>{getGender(info.baseInfo.sex)}</UnText>
                        <UnText size={14}>{info.baseInfo.politicalAffiliation || "暂无政治面貌信息"}</UnText>
                    </View>
                    <View style={styles.line}>
                        <UnText size={14} style={styles.label}>
                            通讯地址：
                        </UnText>
                        <UnText size={14} style={styles.value}>
                            {info.baseInfo.address || "暂无信息"}
                        </UnText>
                        {info.baseInfo.updatedAt && (
                            <UnText size={14} style={styles.value}>
                                更新于：{dayjs(info.baseInfo.updatedAt).format("YYYY-MM-DD hh:mm")}
                            </UnText>
                        )}
                    </View>
                </View>
            </View>
            <Divider />
        </View>
    );
}

function getGender(code: string) {
    if (code === "1") return "男";
    if (code === "2") return "女";
    return "暂无性别信息";
}
