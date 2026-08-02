import React, {memo} from "react";
import {StyleSheet, Text, View} from "react-native";
import {UnOption} from "@/components/un-ui/UnOption.tsx";

interface Category {
    name: string; // 大指标名，如“师德表现”
    qzz: number; // 大指标权重
    items: Item[];
}

interface Option {
    label: string; // 选项文字
    score: number; // 对应分值
    pfdjdmxmb_id: string; // 选项 ID
    checked?: boolean; // 是否默认选中
}

interface Item {
    title: string; // 指标标题
    qzz: number; // 权重
    options: Option[];
    // 其它业务字段
    pjzbxm_id: string;
    pfdjdmb_id: string;
}

export const EvaCategory = memo(
    ({
        cat,
        catIdx,
        onSelect,
    }: {
        cat: Category;
        catIdx: number;
        onSelect: (catIdx: number, itIdx: number, optIdx: number) => void;
    }) => (
        <View style={styles.category}>
            <Text style={styles.categoryName}>
                {cat.name} (权重 {cat.qzz})
            </Text>

            {cat.items.map((it, itIdx) => (
                <UnOption
                    key={it.pfdjdmb_id + it.pjzbxm_id}
                    options={it.options.map(item => ({
                        ...item,
                        key: item.pfdjdmxmb_id,
                        checked: item.checked,
                    }))}
                    label={it.title}
                    onSelect={optIdx => onSelect(catIdx, itIdx, optIdx)}
                />
            ))}
        </View>
    ),
);

const styles = StyleSheet.create({
    category: {
        marginBottom: 10,
    },
    categoryName: {
        fontSize: 16,
        fontWeight: "bold",
        marginBottom: 5,
    },
});
