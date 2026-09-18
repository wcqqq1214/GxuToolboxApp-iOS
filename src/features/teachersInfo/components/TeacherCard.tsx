import React, {memo} from "react";
import {View} from "react-native";
import {Image} from "@rneui/themed";
import {useNavigation} from "@react-navigation/native";
import type {NativeStackNavigationProp} from "@react-navigation/native-stack";
import {Flex, UnCard, UnPressable, UnText} from "@/components/un-ui";
import type {TeacherStackParamList} from "@/features/teachersInfo/type/info.ts";
import {TeacherInfoList} from "@gxutool/adapters/teacherInfo";

const DEFAULT_TEACHER_PHOTO = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

function TeacherCardComponent({item}: {item: TeacherInfoList["list"][number]}) {
    const navigation = useNavigation<NativeStackNavigationProp<TeacherStackParamList>>();

    return (
        <UnPressable onPress={() => navigation.navigate("Detail", {teacher: item})}>
            <UnCard>
                <Flex gap={12} align="flex-start">
                    <View>
                        <Image
                            source={{uri: item.picUrl || DEFAULT_TEACHER_PHOTO}}
                            style={{width: 60, height: 60, borderRadius: 4}}
                        />
                    </View>
                    <Flex gap={4} direction="column" align="flex-start" style={{flex: 1}}>
                        <UnText size={16}>{item.name}</UnText>
                        <UnText size={12}>{item.unit}</UnText>
                    </Flex>
                </Flex>
            </UnCard>
        </UnPressable>
    );
}

export const TeacherCard = memo(TeacherCardComponent);
