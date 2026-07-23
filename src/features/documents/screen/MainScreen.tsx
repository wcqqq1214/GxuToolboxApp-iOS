import {useEffect, useState} from "react";
import {userMgr} from "@/js/mgr/user.ts";
import {ActivityIndicator, ScrollView, StyleSheet, ToastAndroid, TouchableOpacity, View} from "react-native";
import {UnText, vh, vw} from "@/components/un-ui";
import {LoginDialog} from "@/features/documents/components/LoginDialog.tsx";
import {FilePaginator} from "@/features/documents/components/FilePaginator.tsx";
import {FileCard} from "@/features/documents/components/FileCard.tsx";
import {FileTypePicker} from "@/features/documents/components/FileTypePicker.tsx";
import {InputBar} from "@/features/documents/components/InputBar.tsx";
import {Divider, useTheme} from "@rneui/themed";
import {createNativeStackNavigator} from "@react-navigation/native-stack";
import {FileScreen} from "@/features/documents/screen/FileScreen.tsx";
import {useNavigation} from "@react-navigation/native";
import {oaApi} from "@/features/documents/api/oaApi.ts";
import type {FileItem} from "@/type/api/fileSystem/file.ts";

const PAGE_SIZE = 10;

export function PendingFileListScreen() {
    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [isLogin, setIsLogin] = useState<boolean>(false);
    const [isLoginModel, setIsLoginModel] = useState<boolean>(false);
    const [isBusy, setIsBusy] = useState<boolean>(false);

    const [files, setFiles] = useState<FileItem[]>([]);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalPages, setTotalPages] = useState(0);
    const [selectedFileType, setSelectedFileType] = useState<number>(0);
    const [keyword, setKeyword] = useState<string>("");
    const [Account, setAccount] = useState<{username: string; password: string}>({username: "", password: ""});

    const navigation = useNavigation();
    const {theme} = useTheme();

    const style = StyleSheet.create({
        loadingView: {
            display: "flex",
            height: vh(65),
            justifyContent: "center",
            alignItems: "center",
            gap: 4,
        },
        listView: {
            height: vh(65),
            paddingHorizontal: 2,
        },
        emptyView: {
            alignItems: "center",
            marginTop: vh(30),
        },
    });

    /** 从服务端加载指定页 */

    async function loadPage(page: number, fileTypeId?: number) {
        setIsLoading(true);
        const apiFileType = (fileTypeId === 0 && fileTypeId !== undefined) ? null : fileTypeId;

        const res = await oaApi.getFileList({page, pageSize: PAGE_SIZE, fileTypeId: apiFileType, keyword});
        if (res?.code === 200) {
            setFiles(res.result.items);
            setCurrentPage(page);
            setTotalPages(res.result.totalPages);
        } else {
            setFiles([]);
            setTotalPages(0);
        }
        setIsLoading(false);
    }

    /** 翻页 */
    async function goToPage(page: number) {
        if (page < 1 || page > totalPages) return;
        await loadPage(page);
    }

    async function init() {
        const {username, password} = await userMgr.wjxt.getAccount();
        setAccount({username, password});

        if (!username || !password) {
            ToastAndroid.show("请先设置账密", 500);
            setIsLoading(false);
            return;
        }

        const tokenValid = await oaApi.testToken();
        if (tokenValid) {
            setIsLogin(true);
            await loadPage(1);
        } else {
            const loginRes = await oaApi.login(username, password);
            if (loginRes) {
                setIsLogin(true);
                await loadPage(1);
            } else {
                ToastAndroid.show("登录失败，请检查账密", 500);
                setIsLoading(false);
            }
        }
    }

    async function handleLogin(username: string, password: string) {
        try {
            setIsLogin(false);
            setIsBusy(true);
            setFiles([]);
            const loginRes = await oaApi.login(username, password);
            if (loginRes) {
                ToastAndroid.show("登录成功", 500);
                setIsLogin(true);
                setIsLoginModel(false);
                await loadPage(1);
            } else {
                ToastAndroid.show("登录失败，请检查账密", 500);
            }
        } catch (e) {
            console.log(e);
        } finally {
            setIsBusy(false);
        }
    }

    async function logout(){
        await userMgr.wjxt.clearAccountAndToken();
        setIsLogin(false);
        setAccount({username: "", password: ""});
        setFiles([]);
        setTotalPages(0);
        setCurrentPage(0);
        ToastAndroid.show("已清理账号缓存", 500);
        return;
    }

    // @ts-ignore
    useEffect(() => {
        init();
    }, []);

    return (
        <>
            <View style={{padding: vw(5)}}>
                <View
                    style={{
                        display: "flex",
                        flexDirection: "row",
                        justifyContent: "space-between",
                        alignItems: "flex-end",
                        overflow: "visible",
                    }}>
                    <FileTypePicker
                        selectedValue={selectedFileType}
                        onValueChange={async (value) => {
                            setSelectedFileType(value);
                            if (isLogin) await loadPage(1, value);
                        }}
                        enabled={!isLoading && isLogin}
                    />
                    <TouchableOpacity onPress={() => setIsLoginModel(true)}>
                        <UnText size={18} color={theme.colors.primary}>
                            登录
                        </UnText>
                    </TouchableOpacity>
                </View>
                <View style={{marginTop: 8}}>
                    <InputBar
                        keyword={keyword}
                        onKeywordChange={setKeyword}
                        onSubmit={async () => {
                            if (isLogin) await loadPage(1);
                        }}
                        disabled={!isLogin || isLoading}
                    />
                </View>
                <Divider orientation="horizontal" />

                {isLoading ? (
                    <View style={style.loadingView}>
                        <ActivityIndicator size="large" color={theme.colors.primary} />
                        <UnText size={16} color={theme.colors.primary}>
                            内容加载中...
                        </UnText>
                    </View>
                ) : files.length === 0 ? (
                    <View style={style.emptyView}>
                        <UnText size={16}>{isLogin ? "暂无待阅文件" : "未登录"}</UnText>
                    </View>
                ) : (
                    <ScrollView style={style.listView} showsVerticalScrollIndicator={false}>
                        {files.map(item => (
                            <FileCard
                                key={item.id}
                                title={item.fileName}
                                subtitle={item.fileNum + item.showTime.split(" ")[0]}
                                onPress={() => {
                                    // @ts-ignore
                                    navigation.navigate("FileScreen", {fileId: item.id});
                                }}
                            />
                        ))}
                    </ScrollView>
                )}

                {isLogin && (
                    <FilePaginator
                        visible={isLogin}
                        currentPage={currentPage}
                        totalPages={totalPages}
                        onPrev={() => goToPage(currentPage - 1)}
                        onNext={() => goToPage(currentPage + 1)}
                    />
                )}
            </View>
            <LoginDialog
                isVisible={isLoginModel}
                isBusy={isBusy}
                isLogin={isLogin}
                username={Account.username}
                password={Account.password}
                onBackdropPress={() => setIsLoginModel(false)}
                handleLogin={async (username, password) => {
                    await handleLogin(username, password);
                }}
                logout={async () => {
                    await logout();
                }}
            />
        </>
    );
}

export function MainScreen() {
    const Stack = createNativeStackNavigator();

    // @ts-ignore
    return (
        <Stack.Navigator screenOptions={{headerShown: false, animation: "fade"}}>
            <Stack.Screen name={"PendingFileList"} component={PendingFileListScreen} />
            <Stack.Screen name={"FileScreen"} component={FileScreen} />
        </Stack.Navigator>
    );
}
