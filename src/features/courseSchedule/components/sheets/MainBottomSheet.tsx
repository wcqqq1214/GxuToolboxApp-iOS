import {UnBottomSheet} from "@/components/un-ui";
import {SheetState} from "@/features/courseSchedule/components/ScheduleCard.tsx";
import {MenuSheet} from "@/features/courseSchedule/components/sheets/MenuSheet.tsx";
import {SettingSheet} from "@/features/courseSchedule/components/sheets/SettingSheet.tsx";
import React from "react";
import {usePagerView} from "react-native-pager-view";

interface Props {
    sheet: SheetState;
    setSheet: (p: any) => void;

    pageViewRest: Omit<ReturnType<typeof usePagerView>, "AnimatedPagerView" | "ref">;
}

export const MainBottomSheet = ({sheet, setSheet, pageViewRest}: Props) => {
    return (
        <UnBottomSheet
            isVisible={sheet.type === "menu" || sheet.type === "setting"}
            onBackdropPress={() => setSheet({type: "closed"})}
            containerStyle={{padding: "5%"}}>
            {sheet.type === "menu" && <MenuSheet setSheet={setSheet} />}
            {sheet.type === "setting" && <SettingSheet pageViewRest={pageViewRest} />}
        </UnBottomSheet>
    );
};
