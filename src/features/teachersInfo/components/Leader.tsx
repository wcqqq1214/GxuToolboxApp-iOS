import React, {useMemo, useState} from "react";
import {ScrollView, StyleSheet, Text, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {LeaderCard, LeaderDetails} from "@/features/teachersInfo/components/LeaderCard.tsx";
import {type SchoolLeader, type SchoolLeaderList, schoolLeaders} from "@/features/teachersInfo/data/leaders.ts";

type LeaderProps = {
    list?: SchoolLeaderList[];
};

const LEADERS_PER_ROW = 3;

function createRows(leaders: SchoolLeader[]) {
    return Array.from({length: Math.ceil(leaders.length / LEADERS_PER_ROW)}, (_, index) =>
        leaders.slice(index * LEADERS_PER_ROW, (index + 1) * LEADERS_PER_ROW),
    );
}

export function Leader({list = schoolLeaders}: LeaderProps) {
    const [expandedKey, setExpandedKey] = useState<string | null>(null);
    const {theme} = useTheme();
    const styles = useMemo(
        () =>
            StyleSheet.create({
                content: {
                    paddingBottom: 24,
                },
                header: {
                    flexDirection: "row",
                    justifyContent: "center",
                    marginBottom: 12,
                },
                title: {
                    width: "100%",
                    textAlign: "center",
                    color: theme.colors.black,
                    fontSize: 20,
                    fontWeight: "600",
                    marginTop: 10,
                },
                rowBlock: {
                    marginBottom: 12,
                },
                row: {
                    flexDirection: "row",
                    alignItems: "flex-start",
                    justifyContent: "center",
                    columnGap: 8,
                },
                column: {
                    width: "31%",
                },
                empty: {
                    alignItems: "center",
                    paddingVertical: 48,
                },
                emptyText: {
                    color: theme.colors.grey2,
                    fontSize: 14,
                },
            }),
        [theme],
    );

    return (
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
            {list.length > 0 ? (
                list.map(group => (
                    <View key={group.title}>
                        <View style={styles.header}>
                            <Text style={styles.title}>{group.title}</Text>
                        </View>

                        {createRows(group.leader).map((row, rowIndex) => {
                            const expandedLeader = row.find(leader => expandedKey === `${group.title}:${leader.id}`);

                            return (
                                <View key={`${group.title}-row-${rowIndex}`} style={styles.rowBlock}>
                                    <View style={styles.row}>
                                        {row.map(leader => {
                                            const itemKey = `${group.title}:${leader.id}`;

                                            return (
                                                <View key={leader.id} style={styles.column}>
                                                    <LeaderCard
                                                        leader={leader}
                                                        isExpanded={expandedKey === itemKey}
                                                        onToggle={() =>
                                                            setExpandedKey(current =>
                                                                current === itemKey ? null : itemKey,
                                                            )
                                                        }
                                                    />
                                                </View>
                                            );
                                        })}
                                    </View>

                                    {expandedLeader ? <LeaderDetails leader={expandedLeader} /> : null}
                                </View>
                            );
                        })}
                    </View>
                ))
            ) : (
                <View style={styles.empty}>
                    <Text style={styles.emptyText}>暂无学校领导信息</Text>
                </View>
            )}
        </ScrollView>
    );
}
