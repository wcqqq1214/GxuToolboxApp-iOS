// import React from "react";
// import {SafeAreaView, ScrollView, View, Text, TouchableOpacity, StyleSheet} from "react-native";
//
// interface ExamItem {
//     xnmmc: string;
//     kcmc: string;
//     cj: string;
//     // 以下在详情页展示
//     jxb_id: string;
//     cjbdsj: string;
//     xf: string;
//     jd: string;
//     jxbmc: string;
//     jsxm: string;
// }
//
// interface props {
//     data: ExamItem[];
//     expandedId: string | null;
//     onRowPress: (id: string) => void;
//     onExpandToggle: (id: string | null) => void;
//     usualScore: {[key: string]: any};
// }
//
// export default function ExpandTable({data, expandedId, onRowPress, onExpandToggle, usualScore}: props) {
//     const handlePressRow = (item: ExamItem) => {
//         const newExpandedId = expandedId === item.jxb_id ? null : item.jxb_id;
//         onExpandToggle(newExpandedId);
//
//         if (newExpandedId) {
//             onRowPress(item.jxb_id);
//         }
//     };
//
//     return (
//         <SafeAreaView style={styles.container}>
//             <ScrollView>
//                 <View style={styles.row}>
//                     <Text style={styles.cellLeft}>{"       学年   "}</Text>
//                     <Text style={styles.cellCenter}>{" 课程名称"}</Text>
//                     <Text style={styles.cellRight}>{"成绩"}</Text>
//                 </View>
//                 {data.map((item, index) => (
//                     /* 外层 View 必须加 key，否则 React 会报警告 */
//                     <View key={item.kcmc}>
//                         {/* 可点击的行 */}
//                         <TouchableOpacity activeOpacity={0.7} onPress={() => handlePressRow(item)}>
//                             <View style={styles.row}>
//                                 <Text style={styles.cellLeft}>{item.xnmmc}</Text>
//                                 <Text style={styles.cellCenter}>{item.kcmc}</Text>
//                                 <Text style={styles.cellRight}>{item.cj}</Text>
//                             </View>
//                         </TouchableOpacity>
//
//                         {expandedId === item.jxb_id && (
//                             <View style={styles.expandedContainer}>
//                                 {usualScore[item.jxb_id]?.items?.map((score, index) => (
//                                     <View key={index} style={styles.scoreItem}>
//                                         <Text style={styles.scoreText}>项目: {score.xmblmc || "暂无"}</Text>
//                                         <Text style={styles.scoreText}>成绩: {score.xmcj || "暂无"}</Text>
//                                     </View>
//                                 )) || <Text style={styles.detailText}>正在加载...</Text>}
//                                 <View key={index} style={styles.scoreItem}>
//                                     <Text style={styles.scoreText}>成绩发布时间: {item.cjbdsj || "暂无"}</Text>
//                                     <Text style={styles.scoreText}>学分: {item.xf || "暂无"}</Text>
//                                     <Text style={styles.scoreText}>绩点: {item.jd || "暂无"}</Text>
//                                     <Text style={styles.scoreText}>教学班: {item.jxbmc || "暂无"}</Text>
//                                     <Text style={styles.scoreText}>教师: {item.jsxm || "暂无"}</Text>
//                                 </View>
//                             </View>
//                         )}
//                     </View>
//                 ))}
//             </ScrollView>
//         </SafeAreaView>
//     );
// }
//
// const styles = StyleSheet.create({
//     container: {
//         flex: 1,
//         backgroundColor: "#fff",
//     },
//     scoreItem: {
//         paddingVertical: 8,
//         paddingHorizontal: 12,
//         marginVertical: 4,
//         backgroundColor: "#f8f9fa",
//     },
//     scoreText: {
//         fontSize: 14,
//         color: "#333",
//         marginBottom: 2,
//     },
//     row: {
//         flexDirection: "row",
//         alignItems: "center",            // 垂直居中
//         paddingVertical: 12,
//         paddingHorizontal: 8,
//         borderWidth: 1,                  // 全边框
//         borderColor: "#007bff",          // 蓝色
//         marginBottom: 4,                 // 行与行之间的空隙
//     },
//     cellLeft: {
//         fontSize: 16,
//         color: "#333",
//         textAlign: "left",
//     },
//     cellCenter: {
//         marginLeft: 30,
//         flex: 1,                         // 占满中间剩余空间
//         fontSize: 16,
//         color: "#333",
//         textAlign: "left",               // 文字开头对齐
//         paddingHorizontal: 8,            // 左右留空隙
//     },
//     cellRight: {
//         fontSize: 16,
//         color: "#333",
//         textAlign: "right",
//     },
//     expandedContainer: {
//         backgroundColor: "#f5f5f5",
//         paddingHorizontal: 20,
//         paddingVertical: 12,
//     },
//     detailText: {
//         fontSize: 14,
//         color: "#666",
//         lineHeight: 20,
//     },
// });
