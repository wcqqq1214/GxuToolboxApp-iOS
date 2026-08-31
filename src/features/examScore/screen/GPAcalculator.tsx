import {Modal, ScrollView, StyleSheet, TouchableOpacity, View} from "react-native";
import {ChooseTerm} from "@/components/tool/infoQuery/examInfo/ChooseTerm.tsx";
import {Text, useTheme} from "@rneui/themed";
import {useState} from "react";
import {useGpa} from "@/hooks/useGpa.ts";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {RouteProp, useRoute} from "@react-navigation/native";
import {useScore} from "@/features/examScore/hooks/useScore.ts";
import {SchoolTermValue} from "@/type/global.ts";
import {calculatePoint} from "@/features/examScore/component/ExamScoreTable.tsx";

export function GPAcalculator() {
    const {theme} = useTheme();
    const route = useRoute<RouteProp<{params: {year?: number; term?: number}}, "params">>();

    const [year, setYear] = useState<number | "" | undefined>(route.params?.year);
    const [term, setTerm] = useState<SchoolTermValue | undefined>(route.params?.term);

    const {scores} = useScore(year, term);
    const {gpa,wam} = useGpa(scores);
    const [showModal, setShowModal] = useState<boolean>(false);
    const [showWam,setShowWam]=useState<boolean>(false);

    const styles = StyleSheet.create({
        container: {
            flex: 1,
        },
        listContainer: {
            paddingHorizontal: 16,
        },
        headerRow: {
            flexDirection: "row",
            justifyContent: "space-between",
            paddingVertical: 10,
            borderBottomWidth: 2,
            borderBottomColor: theme.colors.primary,
            marginBottom: 5,
        },
        headerText: {
            fontWeight: "bold",
            fontSize: 16,
            color: theme.colors.black,
            flex: 1,
        },
        scoreRow: {
            flexDirection: "row",
            justifyContent: "space-between",
            paddingVertical: 12,
            borderBottomWidth: 1,
            borderBottomColor: theme.colors.grey4,
        },
        courseName: {
            flex: 2,
            fontSize: 15,
            color: theme.colors.black,
        },
        creditText: {
            flex: 1,
            textAlign: "right",
            fontSize: 15,
            color: theme.colors.grey1,
        },
        scoreText: {
            flex: 1,
            textAlign: "center",
            fontSize: 15,
            fontWeight: "bold",
            color: theme.colors.black,
        },
        gpaContainer: {
            marginHorizontal: 10,
            marginTop: 10,
            padding: 20,
            backgroundColor: theme.colors.white,
            borderRadius: 15,
            alignItems: "center",
            justifyContent: "center",
        },
        gpaValue: {
            fontSize: 32,
            fontWeight: "bold",
            color: theme.colors.primary,
        },
        listTitle: {
            marginHorizontal: 15,
            marginTop: 15,
            marginBottom: 5,
            fontSize: 16,
            fontWeight: "bold",
            color: theme.colors.grey1,
        },
        overlay: {
            flex: 1,
            backgroundColor: "rgba(0,0,0,0.4)",
            justifyContent: "center",
            alignItems: "center",
            padding: 16,
        },
        modalCard: {
            width: "88%",
            maxWidth: "90%",
            borderRadius: 14,
            backgroundColor: theme.colors.white,
            paddingVertical: 16,
            paddingHorizontal: 16,
            shadowColor: "#000",
            shadowOpacity: 0.2,
            shadowRadius: 12,
            shadowOffset: {width: 0, height: 6},
            elevation: 6,
            maxHeight: "80%",
        },
        modalTitle: {
            fontSize: 20,
            fontWeight: "bold",
            marginBottom: 10,
            color: theme.colors.black,
            textAlign: "center",
        },
        modalContent: {
            fontSize: 16,
            marginBottom: 10,
            color: theme.colors.black,
        },
        modalCloseButton: {
            fontSize: 16,
            fontWeight: "bold",
            color: theme.colors.primary,
            textAlign: "center",
            marginTop: 10,
        },
    });

    return (
        <View style={styles.container}>
            <ChooseTerm
                onTermSelect={(Year, Term) => {
                    setYear(Year);
                    setTerm(+Term);
                }}
            />
            <View style={styles.gpaContainer}>
                <Text style={styles.gpaValue}>
                    {showWam?`WAM:${wam.toFixed(2)}`:`GPA:${gpa.toFixed(3)}`}
                </Text>
            </View>
            <View style={[styles.listTitle, {flexDirection: "row", alignItems: "center",justifyContent:"space-between"}]}>
                <View style={{flexDirection:"row",alignItems:"center"}}>
                    <Text style={{fontSize: 18, marginRight: 5}}>计算方法</Text>
                    <TouchableOpacity
                       onPress={() => {
                           setShowModal(true);
                        }}>
                       <Icon type="fontawesome" name="circle-question" color={theme.colors.primary} size={18} />
                    </TouchableOpacity>
                </View>
                <TouchableOpacity
                    onPress={()=>setShowWam(prev=>!prev)}
                    style={{backgroundColor:theme.colors.primary,paddingVertical:10,paddingHorizontal:12,borderRadius:6}}>
                    <Text style={{color:"white",fontSize:16,fontWeight:"bold"}}>
                        {showWam?"平均学分绩点":"加权平均成绩"}
                    </Text>
                </TouchableOpacity>
            </View>
            <ScrollView style={styles.listContainer}>
                {scores && scores.length > 0 && (
                    <View style={styles.headerRow}>
                        <Text style={[styles.headerText, {flex: 2, textAlign: "left"}]}>数据来源</Text>
                        <Text style={[styles.headerText, {textAlign: "center"}]}>绩点</Text>
                        <Text style={[styles.headerText, {textAlign: "right"}]}>学分</Text>
                    </View>
                )}
                {scores?.map((item, index) => (
                    <View key={index} style={styles.scoreRow}>
                        <Text style={styles.courseName}>{item.course_name}</Text>
                        <Text style={styles.scoreText}>{calculatePoint(item.score)}</Text>
                        <Text style={styles.creditText}>{item.credit.toFixed(1)}</Text>
                    </View>
                ))}
            </ScrollView>
            <Modal visible={showModal} animationType="fade" transparent>
                <View style={styles.overlay}>
                    <View style={styles.modalCard}>
                        <Text style={styles.modalTitle}>计算方法</Text>
                        <ScrollView>
                            <Text style={styles.modalContent}>
                                文本来源：《广西大学普通本科学生课程修读、考核及成绩管理办法（2019年修订）》{"\n"}
                                为了检查学生学习质量，学校采用课程学分绩点、平均学分绩点、加权平均成绩来衡量学生学习的质量。
                                {"\n"}
                                （一）课程学分绩点按以下简化公式计算：
                                课程的学分绩点＝[（课程考核成绩÷课程考核满分值）×100]/10－5{"\n"}
                                其中，考核不合格未取得学分的课程，其学分绩点为零。{"\n"}
                                （二）平均学分绩点按下式计算： 平均学分绩点＝∑（课程学分绩点×取得的课程学分×K）/ ∑
                                修读课程学分{"\n"}
                                其中，取得的课程学分，指修读课程中已及格课程所对应的学分；课程考核总评成绩（或折算成绩）达到合格标准（即百分制60分及以上或五级制及格及以上）的即取得学分；K为课程系数，没有特别说明时，K取值为1。
                                {"\n"}
                                （三）加权平均成绩按下式计算：
                                加权平均成绩＝∑[（课程考核成绩÷课程考核满分值）×100×修读课程学分×K] / ∑ 修读课程学分
                                {"\n"}
                                （四）平均学分绩点按学期计算的为学期平均学分绩点，按学年计算的为学年平均学分绩点，从入学后不分学期累计计算的为累计平均学分绩点，按入学后至毕业计算的为毕业平均学分绩点。加权平均成绩的计算方法与上述方法一致。
                                {"\n"}
                                （五）原则上计算学生课程学分绩点、平均学分绩点、加权平均成绩时，计算结果一般按四舍五入法保留至小数后两位。
                            </Text>
                        </ScrollView>
                        <TouchableOpacity onPress={() => setShowModal(false)}>
                            <Text style={styles.modalCloseButton}>关闭</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </Modal>
        </View>
    );
}
