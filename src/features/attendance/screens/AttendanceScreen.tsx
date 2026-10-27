import {useState} from "react";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {ScrollView} from "react-native";
import {ChooseTerm} from "@/components/tool/infoQuery/examInfo/ChooseTerm.tsx";
import {Tab} from "@rneui/themed";
import {QuickLogin} from "@/features/attendance/components/QuickLogin.tsx";
import {RecordScreen} from "@/features/attendance/screens/RecordScreen.tsx";
import {TableScreen} from "@/features/attendance/screens/TableScreen.tsx";

export function AttendanceScreen() {
    const [selectedTerm, setSelectedTerm] = useState<{year: number; term: 1 | 2} | null>(null);
    const [activeTab, setActiveTab] = useState(0);
    const {authState} = useAttendanceAuth();

    return (
        <ScrollView style={{flex: 1}} stickyHeaderIndices={[2]}>
            <QuickLogin visible={authState.status !== "authenticated"} />

            <ChooseTerm
                includeWholeLife={false}
                includeWholeYear={false}
                vacationDefault={"past"}
                onTermSelect={(Year, Term) => {
                    if (Year === "" || (Term !== "1" && Term !== "2")) return;
                    setSelectedTerm({year: Year, term: Term === "1" ? 1 : 2});
                }}
            />

            <Tab value={activeTab} onChange={setActiveTab}>
                <Tab.Item title="考勤课表" />
                <Tab.Item title="考勤记录" />
            </Tab>

            {activeTab === 0 ? (
                <TableScreen selectedTerm={selectedTerm} />
            ) : (
                <RecordScreen selectedTerm={selectedTerm} />
            )}
        </ScrollView>
    );
}
