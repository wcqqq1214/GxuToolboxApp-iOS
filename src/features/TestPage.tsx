import React, {useCallback, useState} from "react";
import {ScrollView, StyleSheet, View} from "react-native";
import {Button, Text, useTheme} from "@rneui/themed";
import {expoDb as getDB} from "@/core/db";
import {useFocusEffect} from "@react-navigation/native";
import {ScheduleDataDebugPanel} from "@/features/courseSchedule/components/ScheduleDataDebugPanel";
import {MenuSheet} from "@/features/courseSchedule/components/sheets/MenuSheet.tsx";
import {UnBottomSheet} from "@/components/un-ui";

type Scalar = string | number | boolean | null;

type TableColumn = {
    cid: number;
    name: string;
    type: string;
    notnull: number;
    dflt_value: Scalar;
    pk: number;
};

type TableSnapshot = {
    name: string;
    type: string;
    sql: string | null;
    columns: TableColumn[];
    rows: Record<string, Scalar>[];
    rowCount: number;
};

type DatabaseSnapshot = {
    dbPath: string;
    tables: TableSnapshot[];
};

const ROW_LIMIT = 200;
const IDENTIFIER_QUOTE = String.fromCharCode(34);

/**
 * 作者：NieYing
 * 作用：把 SQLite 标识符转成安全的双引号形式，用于只能拼接表名的 PRAGMA 和 SELECT。
 * 入参：
 * - value：来自 sqlite_schema 的表名或视图名，不接受用户手写 SQL 片段。
 * 出参：
 * - 可直接嵌入 SQL 的标识符字符串，内部双引号会被转义。
 * 修改注意：
 * - 该函数是调试页拼接 SQL 的边界；修改前请确认不能引入任意 SQL 注入入口。
 */
function quoteIdentifier(value: string) {
    return IDENTIFIER_QUOTE + value.replace(/"/g, IDENTIFIER_QUOTE + IDENTIFIER_QUOTE) + IDENTIFIER_QUOTE;
}

/**
 * 作者：NieYing
 * 作用：读取当前 SQLite 数据库的表清单、建表语句、列信息和有限行数的数据快照。
 * 入参：
 * - 无。数据库连接由 core/db 的 getDB 统一提供。
 * 出参：
 * - 返回数据库路径和每张表的调试快照；读取失败会向上抛出异常供页面展示。
 * 修改注意：
 * - 该函数只服务开发调试页；不要在业务流程依赖它，也不要移除 ROW_LIMIT 造成页面卡死。
 */
async function readDatabaseSnapshot(): Promise<DatabaseSnapshot> {
    const db = getDB;
    const schemaResult = await db.execute(
        "SELECT name, type, sql FROM sqlite_schema WHERE type IN ('table', 'view') ORDER BY type, name",
    );
    const tables = await Promise.all(
        schemaResult.rows.map(async table => {
            const name = String(table.name);
            const quotedName = quoteIdentifier(name);
            const columnResult = await db.execute(`PRAGMA table_info(${quotedName})`);
            const countResult =
                table.type === "table" ? await db.execute(`SELECT COUNT(*) AS count FROM ${quotedName}`) : null;
            const rowsResult = await db.execute(`SELECT * FROM ${quotedName} LIMIT ${ROW_LIMIT}`);
            const count = countResult?.rows[0]?.count;

            return {
                name,
                type: String(table.type),
                sql: table.sql === null ? null : String(table.sql),
                columns: columnResult.rows as TableColumn[],
                rows: rowsResult.rows as Record<string, Scalar>[],
                rowCount: typeof count === "number" ? count : rowsResult.rows.length,
            };
        }),
    );

    return {
        dbPath: db.getDbPath(),
        tables,
    };
}

function formatValue(value: Scalar) {
    if (value === null) return "NULL";
    if (typeof value === "boolean") return value ? "true" : "false";
    return String(value);
}

export function TestPage() {
    const [tab, setTab] = useState<"schedule" | "database" | "diy">("diy");
    return (
        <View style={{flex: 1}}>
            <View style={{flexDirection: "row", gap: 8, padding: 12}}>
                <Button type={tab === "schedule" ? "solid" : "outline"} onPress={() => setTab("schedule")}>
                    课表钩子
                </Button>
                <Button type={tab === "database" ? "solid" : "outline"} onPress={() => setTab("database")}>
                    SQLite
                </Button>
                <Button type={tab === "diy" ? "solid" : "outline"} onPress={() => setTab("diy")}>
                    空白页
                </Button>
            </View>
            {tab === "schedule" && <DatabaseDebugPage />}
            {tab === "database" && <ScheduleDataDebugPanel />}
            {tab === "diy" && <DIY />}
        </View>
    );
}

const DIY = () => {
    const [sheet, setSheet] = useState(true);
    return (
        <><UnBottomSheet isVisible={sheet} containerStyle={{padding: "5%"}}>
            <MenuSheet setSheet={setSheet} />
        </UnBottomSheet></>
    );
};

function DatabaseDebugPage() {
    const {theme} = useTheme();
    const [snapshot, setSnapshot] = useState<DatabaseSnapshot | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);

    const refresh = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            setSnapshot(await readDatabaseSnapshot());
        } catch (e) {
            setSnapshot(null);
            setError(e instanceof Error ? e.message : String(e));
        } finally {
            setLoading(false);
        }
    }, []);

    useFocusEffect(
        useCallback(() => {
            refresh();
        }, [refresh]),
    );

    return (
        <ScrollView contentContainerStyle={styles.container}>
            <View style={styles.header}>
                <View style={styles.headerText}>
                    <Text style={styles.title}>SQLite 调试页</Text>
                    <Text style={styles.muted}>{snapshot?.dbPath ?? "正在读取数据库路径"}</Text>
                </View>
                <Button size="sm" loading={loading} onPress={refresh}>
                    刷新
                </Button>
            </View>

            {error ? (
                <View style={[styles.panel, styles.errorPanel]}>
                    <Text style={styles.errorTitle}>读取失败</Text>
                    <Text style={styles.errorText}>{error}</Text>
                </View>
            ) : null}

            {!error && snapshot?.tables.length === 0 ? (
                <View style={styles.panel}>
                    <Text style={styles.muted}>当前数据库没有表。</Text>
                </View>
            ) : null}

            {snapshot?.tables.map(table => (
                <View
                    key={`${table.type}-${table.name}`}
                    style={[
                        styles.panel,
                        {
                            backgroundColor: theme.colors.background,
                            borderColor: theme.colors.grey4,
                        },
                    ]}>
                    <View style={styles.tableHeader}>
                        <Text style={styles.tableTitle}>{table.name}</Text>
                        <Text style={styles.badge}>
                            {table.type} / {table.rowCount} 行
                        </Text>
                    </View>

                    {table.sql ? <Text style={styles.sql}>{table.sql}</Text> : null}

                    <Text style={styles.sectionTitle}>列</Text>
                    <View style={styles.grid}>
                        {table.columns.map(column => (
                            <View key={`${table.name}-${column.cid}`} style={styles.columnItem}>
                                <Text style={styles.columnName}>{column.name}</Text>
                                <Text style={styles.muted}>
                                    {column.type || "ANY"}
                                    {column.pk ? " / PK" : ""}
                                    {column.notnull ? " / NOT NULL" : ""}
                                </Text>
                            </View>
                        ))}
                    </View>

                    <Text style={styles.sectionTitle}>
                        数据{table.rowCount > ROW_LIMIT ? `（前 ${ROW_LIMIT} 行）` : ""}
                    </Text>
                    {table.rows.length === 0 ? (
                        <Text style={styles.muted}>无数据</Text>
                    ) : (
                        table.rows.map((row, rowIndex) => (
                            <View key={`${table.name}-row-${rowIndex}`} style={styles.rowItem}>
                                <Text style={styles.rowIndex}>#{rowIndex + 1}</Text>
                                {Object.entries(row).map(([key, value]) => (
                                    <View key={`${table.name}-${rowIndex}-${key}`} style={styles.cell}>
                                        <Text style={styles.cellKey}>{key}</Text>
                                        <Text style={styles.cellValue}>{formatValue(value as Scalar)}</Text>
                                    </View>
                                ))}
                            </View>
                        ))
                    )}
                </View>
            ))}
        </ScrollView>
    );
}

const styles = StyleSheet.create({
    container: {
        padding: 16,
        gap: 12,
    },
    header: {
        flexDirection: "row",
        alignItems: "center",
        gap: 12,
    },
    headerText: {
        flex: 1,
        gap: 4,
    },
    title: {
        fontSize: 20,
        fontWeight: "700",
    },
    muted: {
        color: "#6b7280",
        fontSize: 12,
        lineHeight: 18,
    },
    panel: {
        borderWidth: StyleSheet.hairlineWidth,
        borderRadius: 8,
        padding: 12,
        gap: 10,
    },
    errorPanel: {
        backgroundColor: "#fff1f2",
        borderColor: "#fecdd3",
    },
    errorTitle: {
        color: "#be123c",
        fontWeight: "700",
    },
    errorText: {
        color: "#be123c",
        fontSize: 12,
        lineHeight: 18,
    },
    tableHeader: {
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        gap: 12,
    },
    tableTitle: {
        flex: 1,
        fontSize: 16,
        fontWeight: "700",
    },
    badge: {
        color: "#374151",
        fontSize: 12,
    },
    sql: {
        padding: 8,
        borderRadius: 6,
        backgroundColor: "#111827",
        color: "#f9fafb",
        fontSize: 11,
        lineHeight: 16,
    },
    sectionTitle: {
        fontSize: 13,
        fontWeight: "700",
    },
    grid: {
        gap: 8,
    },
    columnItem: {
        paddingVertical: 6,
        paddingHorizontal: 8,
        borderRadius: 6,
        backgroundColor: "#f3f4f6",
    },
    columnName: {
        color: "#111827",
        fontWeight: "600",
    },
    rowItem: {
        gap: 6,
        padding: 8,
        borderRadius: 6,
        backgroundColor: "#f9fafb",
    },
    rowIndex: {
        color: "#6b7280",
        fontSize: 12,
        fontWeight: "700",
    },
    cell: {
        gap: 2,
    },
    cellKey: {
        color: "#4b5563",
        fontSize: 12,
        fontWeight: "700",
    },
    cellValue: {
        color: "#111827",
        fontSize: 12,
        lineHeight: 18,
    },
});
