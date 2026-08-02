import {Pressable, PressableProps} from "react-native";
import {useUserConfig} from "@/hooks/useUserConfig";

export type UnPressableProps = PressableProps;

export function UnPressable(props: UnPressableProps) {
    const store = useUserConfig().store;
    const ripple = store(s => s.theme.ripple);

    const android_ripple = props.android_ripple !== undefined ? props.android_ripple : ripple;

    return <Pressable {...props} android_ripple={android_ripple} />;
}
