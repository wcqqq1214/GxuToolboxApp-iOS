import React, {useCallback, useState} from "react";
import {ActivityIndicator, FlatList, StyleSheet, ToastAndroid, View} from "react-native";
import {Flex, UnCard, UnPressable, UnText, vh, vw} from "@/components/un-ui";
import {Button, Divider, Image, Input, useTheme} from "@rneui/themed";
import {teacherInfoApi} from "@/js/info/teacherInfo.ts";
import {SimpleTeacherInfo} from "@/type/api/teacherInfo/info.ts";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {DetailInfoScreen} from "@/screens/tool/other/teacherInfo/DetailInfoScreen.tsx";
import {createNativeStackNavigator} from "@react-navigation/native-stack";
import {useNavigation} from "@react-navigation/native";

type LetterProps = {
    label: string;
    onClick: () => void;
};

export function Letter(props: LetterProps) {
    return (
        <UnPressable
            style={{
                width: "20%",
                height: vw(15),
                marginVertical: 4,
                alignItems: "center",
                justifyContent: "center",
            }}
            onPress={() => {
                props.onClick();
            }}>
            <UnText size={20}>{props.label}</UnText>
        </UnPressable>
    );
}

type ItemProps = {
    item: SimpleTeacherInfo;
};

type SelectorProps = {
    list: string[];
    onSelect: (letter: string) => void;
};

export function LetterSelector(props: SelectorProps) {
    const theme = useTheme().theme;

    const style = StyleSheet.create({
        base: {
            justifyContent: "center",
            backgroundColor: Color.mix(theme.colors.primary, theme.colors.background, 0.7).rgbaString,
            paddingHorizontal: vw(2),
            paddingVertical: vh(1),
            borderRadius: 4,
            opacity: 0.8,
        },
        layout: {
            flexDirection: "row",
            flexWrap: "wrap",
            justifyContent: "space-between",
        },
    });

    return (
        <View style={style.base}>
            <UnText size={18} style={{textAlign: "center"}}>
                点击字母按姓氏查询
            </UnText>
            <Divider />
            <View style={style.layout}>
                {props.list.map((item, index) => (
                    <Letter
                        key={index}
                        label={item}
                        onClick={() => {
                            props.onSelect(item);
                        }}
                    />
                ))}
            </View>
        </View>
    );
}

export function QueryInfoItem(props: ItemProps) {
    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

    const {theme} = useTheme();
    const {store} = useUserConfig();

    const navigation = useNavigation();

    return (
        <UnPressable
            onPress={() => {
                // @ts-ignore
                navigation.navigate("DetailInfo", {teacher: props.item});
            }}>
            <UnCard>
                <Flex gap={12} align="flex-start">
                    <View>
                        <Image
                            source={{uri: props.item.pic ? props.item.pic : iconUrl}}
                            style={{width: 60, height: 60, borderRadius: 4}}
                        />
                    </View>
                    <Flex gap={4} direction="column" align="flex-start" style={{flex: 1}}>
                        <UnText size={16}>{props.item.XM}</UnText>
                        <UnText size={12}>{props.item.dwmc}</UnText>
                    </Flex>
                </Flex>
            </UnCard>
        </UnPressable>
    );
}

export function InfoQueryScreen() {
    const [teacherInfoList, setTeacherInfoList] = useState([]);
    const [curPage, setCurPage] = useState<number>(1);
    const [totalResults, setTotalResults] = useState<number>();

    const [keyWord, setKeyWord] = useState<string>();
    const [selectedLetter, setSelectedLetter] = useState<string>("");

    const [hasMore, setHasMore] = useState(true);
    const [isSearching, setIsSearching] = useState(false);

    const PAGE_SIZE = 12;
    const lettersList = [
        "A",
        "B",
        "C",
        "D",
        "E",
        "F",
        "G",
        "H",
        "I",
        "J",
        "K",
        "L",
        "M",
        "N",
        "O",
        "P",
        "Q",
        "R",
        "S",
        "T",
        "U",
        "V",
        "W",
        "X",
        "Y",
        "Z",
    ];
    const style = StyleSheet.create({
        isLoading: {marginTop: 10, flexDirection: "row", justifyContent: "center", gap: 4},
        results: {marginVertical: 10, flexDirection: "row", justifyContent: "space-between"},
    });

    const ListRenderItems = {
        baseItem: useCallback(({item}) => <QueryInfoItem item={item} />, []),

        emptyItem: useCallback(
            () => (
                <View style={{alignItems: "center", marginTop: 200}}>
                    <UnText size={16}>暂无信息</UnText>
                </View>
            ),
            [],
        ),

        separatorItem: useCallback(() => <View style={{height: 12}} />, []),

        footerItem: useCallback(() => {
            if (teacherInfoList.length === 0) return <></>;
            return hasMore ? (
                <View style={style.isLoading}>
                    <ActivityIndicator size="small" />
                    <UnText size={14}>加载中...</UnText>
                </View>
            ) : (
                <View style={style.isLoading}>
                    <UnText size={14}>没有更多了</UnText>
                </View>
            );
        }, [hasMore, teacherInfoList]),
    };

    async function getInfo(key: string, page: number, isAppend: boolean = false) {
        try {
            const res = await teacherInfoApi.getBaseInfo(key, page);
            const {list, total} = res.resData;

            setIsSearching(true);
            setTotalResults(total);

            //是否为后续添加的内容
            if (isAppend) {
                setTeacherInfoList(prev => [...prev, ...list]);
            } else {
                //如果不是后续内容，点击后将数据赋值到列表
                setTeacherInfoList(list);
            }

            if (list.length < PAGE_SIZE || page * PAGE_SIZE >= total) {
                setHasMore(false);
            }
        } catch {
            ToastAndroid.show("查询失败", 100);
            return;
        }
    }

    async function getInfoByLetter(letter: string, page: number, isAppend: boolean = false) {
        try {
            const res = await teacherInfoApi.getInfoByFirstLetter(letter, page);
            const {list, total} = res.resData;

            setIsSearching(true);
            setTotalResults(total);

            //是否为后续添加的内容
            if (isAppend) {
                setTeacherInfoList(prev => [...prev, ...list]);
            } else {
                //如果不是后续内容，点击后，查询第一页的内容
                setTeacherInfoList(list);
            }

            if (list.length < PAGE_SIZE || page * PAGE_SIZE >= total) {
                setHasMore(false);
            }

            return list;
        } catch {
            ToastAndroid.show("查询失败", 100);
            return;
        }
    }

    async function handleEndReached() {
        if (!hasMore) return;

        const nextPage = curPage + 1;
        setCurPage(nextPage);

        try {
            if (selectedLetter) {
                await getInfoByLetter(selectedLetter, nextPage, true);
                return;
            } else if (keyWord) {
                await getInfo(keyWord, nextPage, true);
                return;
            }
        } catch {
            ToastAndroid.show("查询失败", 100);
        }
    }

    async function handleKeywordSearch() {
        setSelectedLetter("");
        setCurPage(1);
        setHasMore(true);
        await getInfo(keyWord, 1, false);
    }

    async function handleLetterSelect(letter: string) {
        setKeyWord("");
        setSelectedLetter(letter);
        setCurPage(1);
        setHasMore(true);
        await getInfoByLetter(letter, 1, false);
    }

    return (
        <View
            style={{
                padding: vw(5),
            }}>
            <Input
                placeholder="请输入姓名/单位名称/职称/一级学科"
                value={keyWord}
                onChangeText={(inputName: string) => setKeyWord(inputName)}
            />
            <Button
                onPress={() => {
                    if (!keyWord) {
                        ToastAndroid.show("请先输入内容", 50);
                        setIsSearching(false);
                        setTeacherInfoList([]);
                        return;
                    }
                    handleKeywordSearch();
                }}>
                查询
            </Button>

            {isSearching ? (
                <>
                    <View style={style.results}>
                        <View style={{flexDirection: "row", alignItems: "flex-end", gap: 4}}>
                            <UnText size={24}>查询结果</UnText>
                            <UnText>共有 {totalResults ?? 0} 个结果</UnText>
                        </View>
                        <View style={{justifyContent: "flex-end"}}>
                            <Button
                                size={"sm"}
                                style={{width: vw(20)}}
                                onPress={() => {
                                    setIsSearching(false);
                                    setTeacherInfoList([]);
                                }}>
                                返回
                            </Button>
                        </View>
                    </View>

                    <FlatList
                        style={{height: vh(58)}}
                        data={teacherInfoList}
                        renderItem={ListRenderItems.baseItem}
                        ItemSeparatorComponent={<ListRenderItems.separatorItem />}
                        ListEmptyComponent={<ListRenderItems.emptyItem />}
                        ListFooterComponent={<ListRenderItems.footerItem />}
                        onEndReached={() => {
                            handleEndReached();
                        }}
                        onEndReachedThreshold={0.3}
                    />
                </>
            ) : (
                <View style={{marginVertical: 10}}>
                    <LetterSelector
                        list={lettersList}
                        onSelect={letter => {
                            handleLetterSelect(letter);
                        }}
                    />
                </View>
            )}
        </View>
    );
}

export function TeacherQueryInfoScreen() {
    const Stack = createNativeStackNavigator();

    // @ts-ignore
    return (
        <>
            <Stack.Navigator screenOptions={{headerShown: false, animation: "fade"}}>
                <Stack.Screen name={"QueryInfo"} component={InfoQueryScreen} options={{title: "查询"}} />
                <Stack.Screen name={"DetailInfo"} component={DetailInfoScreen} options={{title: "信息"}} />
            </Stack.Navigator>
        </>
    );
}
