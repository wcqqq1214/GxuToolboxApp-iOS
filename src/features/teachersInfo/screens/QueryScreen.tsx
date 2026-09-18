import React from "react";
import {ActivityIndicator, FlatList, StyleSheet, ToastAndroid, View} from "react-native";
import {Button, Input} from "@rneui/themed";
import {UnText, vw} from "@/components/un-ui";
import {Leader} from "@/features/teachersInfo/components/Leader.tsx";
import {TeacherCard} from "@/features/teachersInfo/components/TeacherCard.tsx";
import {useSearch} from "@/features/teachersInfo/hooks/useSearch.ts";
import type {TeacherInfoList} from "@gxutool/adapters/teacherInfo";

function QueryResultSeparator() {
    return <View style={styles.separator} />;
}

type EmptyQueryResultProps = {
    isLoading: boolean;
    errorMessage: string | null;
    onRetry: () => void;
};

function EmptyQueryResult({isLoading, errorMessage, onRetry}: EmptyQueryResultProps) {
    if (isLoading) {
        return (
            <View style={styles.empty}>
                <ActivityIndicator />
                <UnText size={16}>正在查询教师信息...</UnText>
            </View>
        );
    }

    if (errorMessage) {
        return (
            <View style={styles.empty}>
                <UnText size={16}>{errorMessage}</UnText>
                <Button size="sm" onPress={onRetry}>
                    重试
                </Button>
            </View>
        );
    }

    return (
        <View style={styles.empty}>
            <UnText size={16}>暂无匹配教师</UnText>
        </View>
    );
}

function QueryResultItem({item}: {item: TeacherInfoList["list"][number]}) {
    return <TeacherCard item={item} />;
}

type QueryResultFooterProps = {
    hasItems: boolean;
    hasMore: boolean;
    isLoadingMore: boolean;
    errorMessage: string | null;
    onRetry: () => void;
};

function QueryResultFooter({hasItems, hasMore, isLoadingMore, errorMessage, onRetry}: QueryResultFooterProps) {
    if (!hasItems) return null;

    if (isLoadingMore) {
        return (
            <View style={styles.footer}>
                <ActivityIndicator size="small" />
                <UnText size={14}>加载中...</UnText>
            </View>
        );
    }

    if (errorMessage) {
        return (
            <View style={styles.footerError}>
                <UnText size={14}>{errorMessage}</UnText>
                <Button size="sm" onPress={onRetry}>
                    重试加载
                </Button>
            </View>
        );
    }

    if (!hasMore) {
        return (
            <View style={styles.footer}>
                <UnText size={14}>没有更多了</UnText>
            </View>
        );
    }

    return null;
}

export function QueryScreen() {
    const {
        teacherInfoList,
        keyword,
        setKeyword,
        totalResults,
        hasMore,
        isSearching,
        isSearchingNow,
        isLoadingMore,
        searchErrorMessage,
        loadMoreErrorMessage,
        search,
        retrySearch,
        loadMore,
        retryLoadMore,
        reset,
    } = useSearch();

    const handleSearch = () => {
        if (!keyword.trim()) {
            ToastAndroid.show("请先输入内容", ToastAndroid.SHORT);
            reset();
            return;
        }

        search(keyword);
    };

    return (
        <View style={styles.screen}>
            <Input
                placeholder="请输入姓名/单位名称/职称/一级学科"
                value={keyword}
                onChangeText={setKeyword}
                onSubmitEditing={handleSearch}
                returnKeyType="search"
            />
            <Button loading={isSearchingNow} disabled={isSearchingNow || keyword.trim() === ""} onPress={handleSearch}>
                查询
            </Button>

            {isSearching ? (
                <View style={styles.resultsContainer}>
                    <View style={styles.resultsHeader}>
                        <View style={styles.resultsSummary}>
                            <UnText size={24}>查询结果</UnText>
                            <UnText>共有 {totalResults} 个结果</UnText>
                        </View>
                        <Button size="sm" style={styles.backButton} onPress={reset}>
                            返回
                        </Button>
                    </View>

                    <FlatList
                        style={styles.list}
                        data={teacherInfoList}
                        keyExtractor={item => item.id}
                        renderItem={QueryResultItem}
                        ItemSeparatorComponent={QueryResultSeparator}
                        ListEmptyComponent={
                            <EmptyQueryResult
                                isLoading={isSearchingNow}
                                errorMessage={searchErrorMessage}
                                onRetry={retrySearch}
                            />
                        }
                        ListFooterComponent={
                            <QueryResultFooter
                                hasItems={teacherInfoList.length > 0}
                                hasMore={hasMore}
                                isLoadingMore={isLoadingMore}
                                errorMessage={loadMoreErrorMessage}
                                onRetry={retryLoadMore}
                            />
                        }
                        onEndReached={loadMore}
                        onEndReachedThreshold={0.3}
                    />
                </View>
            ) : (
                <View style={styles.leaders}>
                    <Leader />
                </View>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    screen: {
        flex: 1,
        padding: vw(5),
    },
    resultsContainer: {
        flex: 1,
    },
    resultsHeader: {
        marginVertical: 10,
        flexDirection: "row",
        alignItems: "flex-end",
        justifyContent: "space-between",
    },
    resultsSummary: {
        flexDirection: "row",
        alignItems: "flex-end",
        gap: 4,
    },
    backButton: {
        width: vw(20),
    },
    list: {
        flex: 1,
    },
    separator: {
        height: 12,
    },
    empty: {
        alignItems: "center",
        marginTop: 160,
        gap: 12,
    },
    footer: {
        marginTop: 10,
        flexDirection: "row",
        justifyContent: "center",
        gap: 4,
    },
    footerError: {
        alignItems: "center",
        marginTop: 10,
        gap: 8,
    },
    leaders: {
        flex: 1,
        marginTop: 10,
    },
});
