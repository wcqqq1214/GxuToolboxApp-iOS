import React from "react";
import {createNativeStackNavigator} from "@react-navigation/native-stack";
import {QueryScreen} from "@/features/teachersInfo/screens/QueryScreen.tsx";
import {DetailScreen} from "@/features/teachersInfo/screens/DetailScreen.tsx";
import type {TeacherStackParamList} from "@/features/teachersInfo/type/info.ts";

const Stack = createNativeStackNavigator<TeacherStackParamList>();

export function HomeScreen() {
    return (
        <Stack.Navigator screenOptions={{headerShown: false, animation: "fade"}}>
            <Stack.Screen name="Query" component={QueryScreen} options={{title: "查询"}} />
            <Stack.Screen name="Detail" component={DetailScreen} options={{title: "信息"}} />
        </Stack.Navigator>
    );
}
