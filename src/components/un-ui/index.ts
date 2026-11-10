import {Dimensions} from "react-native";
import Flex, {FlexProps} from "./Flex";
import {Icon, UnIconProps} from "./Icon";
import {NumberInput, NumberInputProps} from "./NumberInput";
import {UnBottomSheet, UnBottomSheetProps} from "./UnBottomSheet";
import {UnRefreshControl} from "./UnRefreshControl.tsx";
import {UnTermSelector, UnTermSelectorProps} from "./UnTermSelector.tsx";
import {UnText, UnTextProps} from "./UnText.tsx";
import {UnCard, UnCardProps} from "@/components/un-ui/UnCard.tsx";
import {UnTooltip} from "@/components/un-ui/UnTooltip.tsx";
import {UnTable, UnTableCol, UnTableCols, UnTableProps} from "@/components/un-ui/UnTable.tsx";
import {UnMultiSelect} from "@/components/un-ui/UnMultiSelect.tsx";
import {UnJsonEditor, UnJsonEditorModalProps, UnJsonEditorProps} from "@/components/un-ui/UnJsonEditor";
import {UnPressable, UnPressableProps} from "@/components/un-ui/UnPressable";

function vw(v: number) {
    return (v / 100) * Dimensions.get("window").width;
}
function vh(v: number) {
    return (v / 100) * Dimensions.get("window").height;
}

export type {
    FlexProps,
    UnBottomSheetProps,
    UnIconProps,
    NumberInputProps,
    UnTermSelectorProps,
    UnTextProps,
    UnCardProps,
    UnJsonEditorModalProps,
    UnJsonEditorProps,
    UnPressableProps,
    UnTableProps,
    UnTableCol,
    UnTableCols,
};
export {Flex, Icon, NumberInput, UnBottomSheet, UnJsonEditor, UnMultiSelect, UnPressable, UnRefreshControl, UnTermSelector, UnText, UnTooltip, UnCard, UnTable, vw, vh};
