import {ScrollView} from "react-native";
import {ScheduleCard} from "@/features/courseSchedule/components/ScheduleCard.tsx";
import React from "react";
import {UpdateCard} from "@/components/UpdateCard.tsx";
import {SafeAreaView} from "react-native-safe-area-context";

export function HomeScreen() {
    return (
        <SafeAreaView style={{flex: 1}}>
            <ScrollView
                bounces={true}
                showsVerticalScrollIndicator={false}
                nestedScrollEnabled={true}
                contentContainerStyle={{gap: 8}}>
                <UpdateCard />
                <ScheduleCard />
            </ScrollView>
        </SafeAreaView>
    );
}
