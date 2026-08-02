import {ImageBackground, StatusBar, StyleSheet, useColorScheme, View, ViewProps} from "react-native";
import {DarkTheme, DefaultTheme, NavigationContainer} from "@react-navigation/native";
import {RootStack} from "@/route/RootStack.tsx";
import React, {useEffect} from "react";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {createTheme, useTheme} from "@rneui/themed";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {UnToastContextProvider} from "@/components/un-ui/UnToast.tsx";
import {MapPickerHost} from "@/features/map/components/MapPickerHost.tsx";
import {cowsay} from "@/js/cowsay.ts";
import {generateUiTheme} from "@/shared/theme.ts";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";

export function Root(props: ViewProps) {
    const {store: ucStore, init: ucInit} = useUserConfig();
    const {theme, updateTheme} = useTheme();
    const {init: courseInit} = useCourseData();
    const {init: conflictInit} = useConflictCourseStore();
    const userConfig = ucStore();
    const colorScheme = useColorScheme();

    useEffect(() => {
        courseInit();
        ucInit();
        conflictInit();
        cowsay({
            text: "恭喜你，成功启动了开发服",
            f: "dragon",
        });
    }, []);

    useEffect(() => {
        const newUiTheme = createTheme(generateUiTheme(userConfig, colorScheme));
        updateTheme(newUiTheme);
    }, [ucStore(s => s.theme), colorScheme]);

    const style = StyleSheet.create({
        backgroundStyle: {
            flex: 1,
            backgroundColor: theme.colors.grey5,
        },
        bg: {
            width: "100%",
            height: "100%",
            flex: 1,
        },
    });

    const currentDefaultNavTheme = colorScheme === "light" ? DefaultTheme : DarkTheme;
    const navigationTheme = {
        ...currentDefaultNavTheme,
        dark: colorScheme === "dark",
        colors: {
            ...currentDefaultNavTheme.colors,
            ...theme.colors,
            background: "transparent",
        },
    };
    return (
        <UnToastContextProvider>
            <View {...props} style={[style.backgroundStyle, props.style]}>
                <ImageBackground
                    style={style.bg}
                    source={{uri: ucStore(s => s.theme.bgUrl)}}
                    loadingIndicatorSource={{uri: ucStore(s => s.theme.bgUrl)}}
                    resizeMode="cover">
                    <StatusBar barStyle={colorScheme === "light" ? "dark-content" : "light-content"} />
                    <NavigationContainer theme={navigationTheme}>
                        <RootStack />
                    </NavigationContainer>
                    <MapPickerHost />
                </ImageBackground>
            </View>
        </UnToastContextProvider>
    );
}
