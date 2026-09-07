import {createNativeStackNavigator} from "@react-navigation/native-stack";
import React, {lazy} from "react";
import {Text, View} from "react-native";
import {WebViewScreen} from "@/screens/WebViewScreen.tsx";
import {HelpButton} from "@/components/header/HelpButton.tsx";

const Stack = createNativeStackNavigator();

const headerTitleEle = ({children, tintColor}: {children: string; tintColor?: string}) => {
    return (
        <View style={{flexDirection: "row", alignItems: "center"}}>
            <Text style={{fontSize: 17, fontWeight: "600", color: tintColor}}>{children}</Text>
            <HelpButton docKey={children} />
        </View>
    );
};

export function RootStack() {
    return (
        <Stack.Navigator
            initialRouteName="main"
            screenOptions={{
                headerShadowVisible: false,
                contentStyle: {backgroundColor: "transparent"},
            }}>
            <Stack.Screen
                name="main"
                options={{headerShown: false}}
                component={lazy(() => import("@/screens/MainTab.tsx"))}
            />
            <Stack.Screen
                name="webViewScreen"
                options={{
                    title: "内置浏览器",
                }}
                component={lazy(() => import("@/screens/WebViewScreen.tsx"))}
            />
            <Stack.Screen
                name="feedback"
                options={{
                    title: "意见反馈",
                    headerTitle: headerTitleEle,
                }}
                component={lazy(() =>
                    import("@/features/feedback/screens/FeedbackView.tsx").then(m => ({
                        default: m.FeedbackView,
                    })),
                )}
            />
            <Stack.Screen
                name="feedbackList"
                options={{title: "我的反馈"}}
                component={lazy(() =>
                    import("@/features/feedback/screens/FeedbackListScreen.tsx").then(m => ({
                        default: m.FeedbackListScreen,
                    })),
                )}
            />
            <Stack.Screen
                name="feedbackDetail"
                options={{title: "反馈详情"}}
                component={lazy(() =>
                    import("@/features/feedback/screens/FeedbackDetailScreen.tsx").then(m => ({
                        default: m.FeedbackDetailScreen,
                    })),
                )}
            />
        </Stack.Navigator>
    );
}
