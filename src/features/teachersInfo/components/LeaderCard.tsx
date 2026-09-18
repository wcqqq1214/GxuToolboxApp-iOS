import React, {memo, useMemo} from "react";
import {Image, Pressable, StyleSheet, Text, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui";
import {Color} from "@/shared/color.ts";
import type {SchoolLeader} from "@/features/teachersInfo/data/leaders.ts";

type LeaderCardProps = {
    leader: SchoolLeader;
    isExpanded: boolean;
    onToggle: () => void;
};

function LeaderCardComponent({leader, isExpanded, onToggle}: LeaderCardProps) {
    const {theme} = useTheme();

    const styles = useMemo(
        () =>
            StyleSheet.create({
                card: {
                    width: "100%",
                    overflow: "hidden",
                    borderWidth: StyleSheet.hairlineWidth,
                    borderColor: theme.colors.grey4,
                    borderRadius: 8,
                    backgroundColor: theme.mode === "dark" ? theme.colors.grey5 : theme.colors.white,
                },
                photo: {
                    width: "100%",
                    aspectRatio: 0.78,
                },
                identity: {
                    alignItems: "center",
                    paddingHorizontal: 6,
                    paddingVertical: 10,
                },
                name: {
                    textAlign: "center",
                    color: theme.colors.black,
                    fontSize: 18,
                    fontWeight: "600",
                    letterSpacing: 0.5,
                },
                toggle: {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 2,
                },
            }),
        [theme],
    );

    return (
        <Pressable
            accessibilityRole="button"
            accessibilityLabel={`${leader.name}，${isExpanded ? "收起职责" : "查看职责"}`}
            accessibilityState={{expanded: isExpanded}}
            onPress={onToggle}
            style={styles.card}>
            <View>
                {leader.photoUrl ? (
                    <Image source={{uri: leader.photoUrl}} style={styles.photo} resizeMode="cover" />
                ) : (
                    <View style={styles.photo} />
                )}
                <View style={styles.identity}>
                    <View style={styles.toggle}>
                        <Text style={styles.name}>{leader.name}</Text>
                        <Icon
                            type="material"
                            name={isExpanded ? "chevron-up" : "chevron-down"}
                            size={16}
                            color={theme.colors.primary}
                        />
                    </View>
                </View>
            </View>
        </Pressable>
    );
}

export const LeaderCard = memo(LeaderCardComponent);

export function LeaderDetails({leader}: {leader: SchoolLeader}) {
    const {theme} = useTheme();
    const styles = useMemo(
        () =>
            StyleSheet.create({
                details: {
                    width: "100%",
                    marginTop: 8,
                    borderRadius: 8,
                    paddingHorizontal: 14,
                    paddingVertical: 12,
                    backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "dark" ? 0.1 : 0.06)
                        .rgbaString,
                },
                position: {
                    color: theme.colors.black,
                    fontSize: 13,
                    fontWeight: "600",
                    lineHeight: 20,
                    textAlign: "center",
                },
                duty: {
                    marginTop: 8,
                    color: theme.colors.black,
                    fontSize: 14,
                    lineHeight: 22,
                    textAlign: "center",
                },
            }),
        [theme],
    );

    return (
        <View style={styles.details}>
            {leader.position ? <Text style={styles.position}>{leader.position}</Text> : null}
            {leader.duties.map((duty, index) => (
                <Text key={`${leader.id}-duty-${index}`} style={styles.duty}>
                    {duty}
                </Text>
            ))}
        </View>
    );
}
