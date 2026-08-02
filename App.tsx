import React, {useEffect, useMemo} from "react";
import {ThemeProvider} from "@rneui/themed";
import {theme} from "@/shared/theme.ts";
import {Root} from "./src/screens/Root.tsx";
import {useColorScheme} from "react-native";
import {SafeAreaProvider} from "react-native-safe-area-context";
import {openAppEvent} from "@/features/feedback/api/event.ts";
import {migrateTemplates} from "@/features/evaluation/store/defaultTemplate.ts";
import {initDB} from "@/core/db.ts";
import {getCurrentStartDay} from "@/features/courseSchedule/repo/startDay.ts";
import {checkOTA, cleanStaleOTA} from "@/core/ota.ts";
import {JwMachine} from "@/core/auth/Jw/JwMachine.ts";
import {syncInfo} from "@/core/repo/userProfileServer.ts";

function safe<T>(p: Promise<T>, label: string) {
    return p.catch(e => console.warn(`${label}:`, e));
}

function App(): React.JSX.Element {
    const colorScheme = useColorScheme();
    const currentTheme = useMemo(
        () => ({
            ...theme,
            mode: colorScheme ?? "light",
        }),
        [colorScheme],
    );

    // 应用初始化
    useEffect(() => {
        // 非 DB、不阻塞首屏：与 DB 初始化并行，各自失败不影响别处
        safe(openAppEvent(), "openAppEvent");
        safe(cleanStaleOTA().then(() => checkOTA()), "checkOTA");

        (async () => {
            // DB 是硬前提，先就绪；失败则后续 DB 依赖任务都会失败，但错误隔离不会崩
            await safe(initDB(), "initDB");
            // 依赖 DB 的任务并行拉取
            await Promise.all([
                safe(getCurrentStartDay(), "getCurrentStartDay"),
                safe(migrateTemplates(), "migrateTemplates"),
                safe(
                    JwMachine.loadAccount().then(a => (a?.username ? syncInfo(a.username) : null)),
                    "syncInfo",
                ),
            ]);
        })();
    }, []);

    return (
        <ThemeProvider theme={currentTheme}>
            <SafeAreaProvider>
                <Root />
            </SafeAreaProvider>
        </ThemeProvider>
    );
}

export default App;
