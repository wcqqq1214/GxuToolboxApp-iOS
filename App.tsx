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
import {checkOTA} from "@/core/ota.ts";

function App(): React.JSX.Element {
    const colorScheme = useColorScheme();
    const currentTheme = useMemo(
        () => ({
            ...theme,
            mode: colorScheme ?? "light",
        }),
        [colorScheme],
    );

    async function init() {
        try {
            await openAppEvent();
            initDB();
            await getCurrentStartDay();
            checkOTA();
        } catch (e) {
            console.warn(e);
        }
    }

    // 应用初始化
    useEffect(() => {
        init();
        migrateTemplates();
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
