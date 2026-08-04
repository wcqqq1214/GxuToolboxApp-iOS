import {useTheme} from "@rneui/themed";
import AntDesign, {AntDesignIconName} from "@react-native-vector-icons/ant-design";
import Ionicons, {IoniconsIconName} from "@react-native-vector-icons/ionicons";
import FontAwesome6, {FontAwesome6RegularIconName} from "@react-native-vector-icons/fontawesome6";
import {MaterialDesignIcons, MaterialDesignIconsIconName} from "@react-native-vector-icons/material-design-icons";
import {FontAwesome6IconProps} from "react-native-vector-icons/FontAwesome6";
import {TextStyle} from "react-native";
import {IconProps} from "react-native-vector-icons/Icon";

export type UnIconProps = Omit<IconProps, "type"> & {
    rotate?: number;
} & (
        | {
              name: AntDesignIconName;
              type: "antdesign";
          }
        | ({
              name: FontAwesome6RegularIconName;
              type: "fontawesome";
          } & FontAwesome6IconProps)
        | {
              name: IoniconsIconName;
              type: "ionicons";
          }
        | {
              name: MaterialDesignIconsIconName;
              type?: "material";
          }
    );

export function Icon({type = "material", name, size = 12, color, rotate, ...props}: UnIconProps) {
    const {theme} = useTheme();
    const iconColor = color || theme.colors.black;
    const rotateStyle: TextStyle | undefined =
        rotate !== undefined ? {transform: [{rotate: `${rotate}deg`}]} : undefined;

    switch (type) {
        case "antdesign":
            return (
                <AntDesign
                    name={name as AntDesignIconName}
                    size={size}
                    color={iconColor}
                    {...props}
                    style={rotateStyle}
                />
            );
        case "fontawesome":
            return (
                <FontAwesome6
                    name={name as FontAwesome6RegularIconName}
                    iconStyle="regular"
                    size={size}
                    color={iconColor}
                    {...props}
                    style={rotateStyle}
                />
            );
        case "ionicons":
            return (
                <Ionicons
                    name={name as IoniconsIconName}
                    size={size}
                    color={iconColor}
                    {...props}
                    style={rotateStyle}
                />
            );
        case "material":
            return (
                <MaterialDesignIcons
                    name={name as MaterialDesignIconsIconName}
                    size={size}
                    color={iconColor}
                    {...props}
                    style={rotateStyle}
                />
            );
        default:
            return (
                <AntDesign
                    name={name as AntDesignIconName}
                    size={size}
                    color={iconColor}
                    {...props}
                    style={rotateStyle}
                />
            );
    }
}
