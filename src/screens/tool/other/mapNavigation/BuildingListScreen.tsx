import BuildingListItem from "@/screens/tool/other/mapNavigation/BuildingListItem.tsx";
import {FlatList, ScrollView, StyleSheet, Text, TouchableOpacity, View} from "react-native";
import {BuildingList} from "@/features/map/data/buildings.ts";
import {useState} from "react";
import {useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";

const buildingTypes = ["全部", ...new Set(BuildingList.map(item => item.type))];

export function BuildingListScreen() {
    const {theme} = useTheme();
    const defaultColor = Color.mix(
        Color(theme.colors.primary),
        Color(theme.colors.background),
        theme.mode === "dark" ? 0.1 : 0.4,
    ).setAlpha(theme.mode === "dark" ? 0.3 : 0.8).rgbaString;

    const [selectedType, setSelectedType] = useState("全部");

    const selectedData =
        selectedType === "全部" ? BuildingList : BuildingList.filter(item => item.type === selectedType);

    return (
        <View style={{flex: 1}}>
            <View>
                <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.filterContainer}>
                    {buildingTypes.map(type => (
                        <TouchableOpacity
                            key={type}
                            style={[
                                styles.filterButton,
                                {borderColor: defaultColor},
                                selectedType === type && {backgroundColor: defaultColor},
                            ]}
                            onPress={() => setSelectedType(type)}>
                            <Text
                                style={[
                                    {color: theme.colors.black},
                                    selectedType === type && styles.selectedFilterButtonText,
                                ]}>
                                {type}
                            </Text>
                        </TouchableOpacity>
                    ))}
                </ScrollView>
            </View>

            <FlatList
                data={selectedData}
                renderItem={({item}) => <BuildingListItem building={item} />}
                keyExtractor={item => item.name}
            />
        </View>
    );
}

const styles = StyleSheet.create({
    filterContainer: {
        paddingVertical: 10,
        paddingHorizontal: 8,
    },
    filterButton: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 20,
        marginHorizontal: 4,
        borderWidth: 1,
    },
    selectedFilterButtonText: {
        color: "#fff",
        fontWeight: "bold",
    },
});
