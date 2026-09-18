import {UnListSection, UnSectionList} from "@/components/un-ui/UnSectionList.tsx";
import {useUserConfig} from "@/hooks/useUserConfig.ts";

export function UserPreferenceSettingIndex() {
    const {store} = useUserConfig();

    const settingList: UnListSection[] = [
        {
            title: "信息显示",
            data: [
                {
                    label: "课程元素详情显示",
                    type: "navigation",
                    value: "CourseItemDetailSetting",
                },
            ],
        },
    ];

    return <UnSectionList sections={settingList} contentContainerStyle={{padding: "5%"}} />;
}
