import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {Button, Image, useTheme} from "@rneui/themed";
import React, {useEffect, useState} from "react";
import {usePagerView} from "react-native-pager-view";
import type {SimpleTeacherInfo} from "@/features/teachersInfo/type/info.ts";
import {Flex, UnBottomSheet, UnCard, UnPressable, UnText, vh} from "@/components/un-ui";
import {DetailList} from "@/features/teachersInfo/components/DetailList.tsx";
import {useDetail} from "@/features/teachersInfo/hooks/useDetail.ts";

const DEFAULT_PHOTO = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

type Props = {
    isVisible: boolean;
    infoList: SimpleTeacherInfo[];
    openPage: number;
    onClose: () => void;
};

export function TeacherSheet(props: Props) {
    const {theme} = useTheme();
    const [selectedTeacher, setSelectedTeacher] = useState<SimpleTeacherInfo>();
    const pagerView = usePagerView({pagesAmount: 2});

    useEffect(() => {
        if (!props.isVisible) return;

        setSelectedTeacher(props.infoList.length === 1 ? props.infoList[0] : undefined);
        pagerView.ref.current?.setPage(props.openPage);
    }, [props.openPage, props.infoList, props.isVisible]);

    return (
        <UnBottomSheet
            isVisible={props.isVisible}
            onBackdropPress={props.onClose}
            containerStyle={{height: vh(80), padding: 0}}>
            <View
                style={{
                    flexDirection: "row",
                    justifyContent: "space-between",
                    paddingHorizontal: 16,
                    paddingVertical: 8,
                    borderBottomColor: theme.colors.grey4,
                    borderBottomWidth: 1,
                }}>
                <UnText size={18}>{pagerView.activePage === 0 ? "检索到以下教师信息" : "教师个人信息"}</UnText>
                {pagerView.activePage !== 0 && (
                    <UnPressable onPress={() => pagerView.ref.current?.setPage(0)}>
                        <UnText size={16}>返回</UnText>
                    </UnPressable>
                )}
            </View>
            <pagerView.AnimatedPagerView
                ref={pagerView.ref}
                style={{width: "100%", flex: 1}}
                initialPage={props.openPage}
                overScrollMode="never"
                orientation="horizontal"
                scrollEnabled={false}
                onPageSelected={pagerView.onPageSelected}>
                <View key="0" collapsable={false} style={{width: "100%", flex: 1}}>
                    <TeacherList
                        onSelect={teacher => {
                            setSelectedTeacher(teacher);
                            pagerView.ref.current?.setPage(1);
                        }}
                        list={props.infoList}
                    />
                </View>
                <View key="1" collapsable={false} style={{width: "100%", flex: 1}}>
                    {selectedTeacher ? <TeacherDetail teacher={selectedTeacher} /> : null}
                </View>
            </pagerView.AnimatedPagerView>
        </UnBottomSheet>
    );
}

type ListProps = {
    onSelect: (teacher: SimpleTeacherInfo) => void;
    list: SimpleTeacherInfo[];
};

function TeacherList({onSelect, list}: ListProps) {
    return (
        <ScrollView>
            {list.length > 0 ? (
                list.map(item => (
                    <UnPressable
                        key={item.id}
                        style={{marginTop: 8, marginHorizontal: 4}}
                        onPress={() => onSelect(item)}>
                        <UnCard>
                            <Flex gap={12} align="flex-start">
                                <Image
                                    source={{uri: item.picUrl || DEFAULT_PHOTO}}
                                    style={{width: 60, height: 60, borderRadius: 4}}
                                />
                                <Flex gap={4} direction="column" align="flex-start" style={{flex: 1}}>
                                    <UnText size={16}>{item.name}</UnText>
                                    <UnText size={12}>{item.unit}</UnText>
                                </Flex>
                            </Flex>
                        </UnCard>
                    </UnPressable>
                ))
            ) : (
                <UnText size={16}>暂无信息</UnText>
            )}
        </ScrollView>
    );
}

type DetailProps = {
    teacher: SimpleTeacherInfo;
};

function TeacherDetail({teacher}: DetailProps) {
    const {data, loading, error, retry} = useDetail(teacher);

    if (loading) {
        return <DetailState message="正在加载教师信息..." />;
    }

    if (error || !data) {
        return <DetailState message={error || "暂无教师信息"} onRetry={retry} />;
    }

    return <DetailList info={data} />;
}

function DetailState({message, onRetry}: {message: string; onRetry?: () => Promise<void>}) {
    return (
        <View style={styles.state}>
            {onRetry ? <UnText size={16}>{message}</UnText> : <ActivityIndicator />}
            {onRetry ? <Button onPress={onRetry}>重试</Button> : <UnText size={16}>{message}</UnText>}
        </View>
    );
}

const styles = StyleSheet.create({
    state: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
        gap: 12,
        padding: 24,
    },
});
