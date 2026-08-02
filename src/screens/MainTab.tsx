import {createBottomTabNavigator} from "@react-navigation/bottom-tabs";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {SettingStack} from "@/route/screens/SettingStack.tsx";
import {ToolboxStack} from "@/route/screens/ToolboxStack.tsx";
import {Color} from "@/shared/color.ts";
import {Button, useTheme} from "@rneui/themed";
import {HomeStack} from "@/route/screens/HomeStack.tsx";
import {useWebView} from "@/hooks/app.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";

const Tab = createBottomTabNavigator();

export default function MainTab() {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);
    const {openInJw} = useWebView();
    const headerRightEle = () => {
        return (
            <Button
                type="clear"
                containerStyle={{marginRight: 10}}
                onPress={() => {
                    openInJw("/xtgl/index_initMenu.html");
                }}>
                打开教务
            </Button>
        );
    };
    return (
        <Tab.Navigator
            screenOptions={{
                headerShadowVisible: false,
                tabBarActiveTintColor: theme.colors.primary,
                headerStyle: {
                    backgroundColor: Color.mix(theme.colors.background, theme.colors.primary, 0.2).setAlpha(
                        ((theme.mode === "dark" ? 0.5 : 0.4) * bgOpacity) / 100,
                    ).rgbaString,
                },
                sceneStyle: {
                    backgroundColor: Color.mix(theme.colors.background, theme.colors.primary, 0.2).setAlpha(
                        ((theme.mode === "dark" ? 0.8 : 0.4) * bgOpacity) / 100,
                    ).rgbaString,
                },
                tabBarStyle: {
                    backgroundColor: Color.mix(theme.colors.background, theme.colors.primary, 0.2).setAlpha(
                        ((theme.mode === "dark" ? 0.9 : 0.75) * bgOpacity) / 100,
                    ).rgbaString,
                    elevation: 0, // Android 去除阴影
                    shadowOpacity: 0, // iOS 去除阴影
                },
                headerRight: headerRightEle,
            }}>
            <Tab.Screen
                name="home"
                options={{
                    headerShown: false,
                    title: "首页",
                    tabBarIcon: props => Icon({name: "home", ...props}),
                }}
                component={HomeStack}
            />
            <Tab.Screen
                name="tool"
                options={{
                    headerShown: false,
                    title: "工具箱",
                    tabBarIcon: props => Icon({name: "toolbox", ...props}),
                }}
                component={ToolboxStack}
            />
            <Tab.Screen
                name="setting"
                options={{
                    title: "设置",
                    headerShown: false,
                    tabBarIcon: props => Icon({name: "cog", ...props}),
                }}
                component={SettingStack}
            />
        </Tab.Navigator>
    );
}
