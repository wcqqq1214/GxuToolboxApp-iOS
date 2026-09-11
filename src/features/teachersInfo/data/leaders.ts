export type SchoolLeader = {
    id: string;
    name: string;
    photoUrl?: string;
    position?: string;
    duties: string[];
};

export type SchoolLeaderList = {
    title: string;
    leader: SchoolLeader[];
};

const xuHuarui: SchoolLeader = {
    id: "xu-huarui",
    name: "徐华蕊",
    photoUrl: "https://www.gxu.edu.cn/__local/E/89/5D/17AF9D4F5EACDE6576DE3FA4FAA_90A54B7E_427E3F.png",
    position: "党委书记",
    duties: ["主持学校党委全面工作。"],
};

const xiaoJianzhuang: SchoolLeader = {
    id: "xiao-jianzhuang",
    name: "肖建庄",
    photoUrl: "https://www.gxu.edu.cn/__local/B/FE/E5/F83FF520BE1C5BF84EC11531A34_283F24DE_8522.jpg",
    position: "党委副书记、校长",
    duties: ["主持学校行政全面工作。"],
};

const jinShunnan: SchoolLeader = {
    id: "jin-shunnan",
    name: "金顺南",
    photoUrl: "https://www.gxu.edu.cn/__local/9/14/D5/D63661453CE9A31BE624B1F63DA_1F67E5BC_95B20.jpg",
    position: "自治区纪委监委驻广西大学纪检监察组组长，校党委副书记、纪委书记",
    duties: ["主持驻校纪检监察组和学校纪委工作。", "分管党委巡察工作领导小组办公室、党委巡察组。"],
};

const ningXuchu: SchoolLeader = {
    id: "ning-xuchu",
    name: "宁旭初",
    photoUrl: "https://www.gxu.edu.cn/__local/C/59/65/43D83300C2CB1687AB4D861A852_A298018F_60C2.jpg",
    position: "党委副书记",
    duties: [
        "负责党建、组织、党校、乡村振兴、统战以及综合协调、督查信访、法治、审计、校友联系、行健文理学院转设等工作。",
        "分管党委办公室、校长办公室（校务督查办公室、法治与法务办公室），党委组织部（中共广西大学委员会党校），党委统战部，机关党委，审计处，校友工作办公室、校友总会、教育发展基金会，行健文理学院（收尾期）。",
    ],
};

const tangZhihua: SchoolLeader = {
    id: "tang-zhihua",
    name: "汤志华",
    photoUrl: "https://www.gxu.edu.cn/__local/E/0B/99/F789A6A63B74C5DC1C3E8ED6578_E7678BBA_814F9.jpg",
    position: "党委副书记",
    duties: [
        "负责宣传、思想政治教育、意识形态、共青团、哲学社会科学研究、继续教育、教育培训、图书信息、档案、部区合建应用经济学一流学科等工作。",
        "联系应用经济学与现代服务业学科群及相关学院和先进思想与文化传播学科群及相关学院。",
        "分管党委宣传部（精神文明建设委员会办公室）、校团委、继续教育学院、中国—东盟经济学院、中国—东盟研究院、图书馆（档案馆）、君武文化研究院。",
    ],
};

const liuXiang: SchoolLeader = {
    id: "liu-xiang",
    name: "刘向",
    photoUrl: "https://www.gxu.edu.cn/__local/0/F2/1E/1BC040BDDB017BB06621D6406BF_FACC1956_673E.png",
    position: "党委常委、副校长",
    duties: [
        "负责学生工作、就业、安全稳定、保卫、社会治安综合治理、疫情防控、工会、计划生育、体委、校办产业、大学科技园建设等工作。",
        "联系共青团工作。",
        "分管党委学生工作部、学生工作处、武装部（就业指导中心），保卫处（治安综合治理委员会办公室），校工会（校医院），资产经营有限公司。",
    ],
};

const liangEnwei: SchoolLeader = {
    id: "liang-enwei",
    name: "梁恩维",
    photoUrl: "https://www.gxu.edu.cn/__local/9/5C/55/584A50CD23DCDFF3DA665529A45_3CC7513D_A401E.jpg",
    position: "党委常委、副校长",
    duties: [
        "负责科研管理、学术期刊建设、财经、智慧校园建设等工作。",
        "联系数理基础和前沿交叉学科群及相关学院。",
        "分管科研院（学术委员会办公室），财务处，信息网络中心（网络安全与信息化办公室）。",
    ],
};

const yuWenjin: SchoolLeader = {
    id: "yu-wenjin",
    name: "于文进",
    photoUrl: "https://www.gxu.edu.cn/__local/2/B1/15/67DB222DFE88B567384BF171447_41F3D421_B8B1A.jpg",
    position: "党委常委、副校长",
    duties: [
        "负责国际合作、国际交流管理、港澳台事务管理、国际留学生管理和服务、后勤服务、基建工程、校园规划建设管理等工作。",
        "联系轻化工程与先进制造学科群及相关学院。",
        "分管国际合作与交流处（留学生管理服务中心、港澳台事务办公室），后勤基建处。",
    ],
};

const zhaoShuangliang: SchoolLeader = {
    id: "zhao-shuangliang",
    name: "赵双良",
    photoUrl: "https://www.gxu.edu.cn/__local/9/15/82/3FEAC0FD657D0E7045D1D6D06FF_74A7D5B0_78A61.jpg",
    position: "党委常委、副校长",
    duties: [
        "负责发展规划，学科建设，“双一流”建设，部区合建，本科生、研究生教育教学与学位管理，教育教学质量监控与评价，学生创新创业，留学生教学、招生，对口支援、高等教育研究、农科新城建设等工作。",
        "联系土木工程与先进材料学科群及相关学院。",
        "分管发展规划处（双一流建设和部区合建办公室）、教务处（教师教学发展中心）、研究生院（学位评定委员会办公室）、教育教学质量监控与评价中心、高等教育研究所、农牧产业发展研究院（广西牧草工作站、新农村发展研究院）。",
    ],
};

const wangXianggao: SchoolLeader = {
    id: "wang-xianggao",
    name: "王祥高",
    photoUrl: "https://www.gxu.edu.cn/__local/D/03/76/58834D475F0955E0034FFC74489_430E8C0B_AA9E2.jpg",
    position: "党委常委、副校长，党委组织部部长",
    duties: [
        "负责人事人才、综合改革试点、教师思想政治和师德师风建设、博士后流动站管理和博士后日常管理、国有资产管理、实验教学与实验装备、招标采购、离退休、关心下一代等工作。主持党委组织部工作，协助分管乡村振兴等工作。",
        "分管党委教师工作部、人力资源处，国有资产与实验室管理处（招标与采购管理中心），离退休工作处。",
    ],
};

const anYonghui: SchoolLeader = {
    id: "an-yonghui",
    name: "安永辉",
    photoUrl: "https://www.gxu.edu.cn/__local/C/D5/8B/FA770876B9DB0A99D252FD50A66_49FE327C_16F4C.jpg",
    position: "学术副校长",
    duties: ["主持土木学院全面行政工作。"],
};

const sunRui: SchoolLeader = {
    id: "sun-rui",
    name: "孙瑞",
    photoUrl: "https://www.gxu.edu.cn/__local/A/85/55/A842F91538D279908A849BDFD45_3A1B6745_2526D.jpg",
    position: "党委常委、党委宣传部部长",
    duties: ["主持党委宣传部（精神文明建设委员会办公室）工作。", "负责网络和期刊等意识形态管理等工作。"],
};

const yaoZuofang: SchoolLeader = {
    id: "yao-zuofang",
    name: "姚作芳",
    photoUrl: "https://www.gxu.edu.cn/__local/9/88/5F/29E0A2047A4194AB69E1BFC42BE_5EBDD7B2_40558.jpg",
    position: "党委常委、校长助理、党委统战部部长",
    duties: ["主持党委统战部工作。"],
};

const qinChengrong: SchoolLeader = {
    id: "qin-chengrong",
    name: "覃程荣",
    photoUrl: "https://www.gxu.edu.cn/__local/4/8A/8B/0CE406F123405C5CC520FAA95F0_DE144F40_7B98E.jpg",
    position: "校长助理",
    duties: ["协助分管轻化工程与先进制造学科群及相关学院。"],
};

const xuQinfa: SchoolLeader = {
    id: "xu-qinfa",
    name: "徐秦法",
    photoUrl: "https://www.gxu.edu.cn/__local/E/C8/39/EFB221BFE68C0EB9D7BE55E844E_737F1620_C7FF.jpg",
    position: "校长助理",
    duties: ["协助分管思政课和课程思政建设、先进思想与文化传播学科群及相关学院。"],
};

const xiaChanglei: SchoolLeader = {
    id: "xia-changlei",
    name: "夏常磊",
    photoUrl: "https://www.gxu.edu.cn/__local/B/FE/2A/CD1EC78B62199B91C7EEB1115AA_8ADF6BCB_11886.jpg",
    position: "校长助理",
    duties: ["协助分管现代农业与大健康学科群及相关学院，协助联系十大现代化支柱产业专项工作专班林产加工及纸业工作组。"],
};

/**
 * 顺序和重复归类均与广西大学官网“现任领导”页面保持一致。
 * 同一位领导兼任多个栏目职务时，会在对应栏目中分别完整展示。
 */
export const schoolLeaders: SchoolLeaderList[] = [
    {title: "党委书记", leader: [xuHuarui]},
    {title: "党委副书记", leader: [xiaoJianzhuang, jinShunnan, ningXuchu, tangZhihua]},
    {title: "校长", leader: [xiaoJianzhuang]},
    {title: "副校长", leader: [liuXiang, liangEnwei, yuWenjin, zhaoShuangliang, wangXianggao]},
    {title: "学术副校长", leader: [anYonghui]},
    {
        title: "党委常委",
        leader: [
            xuHuarui,
            xiaoJianzhuang,
            jinShunnan,
            ningXuchu,
            tangZhihua,
            liuXiang,
            liangEnwei,
            yuWenjin,
            zhaoShuangliang,
            wangXianggao,
            sunRui,
            yaoZuofang,
        ],
    },
    {title: "校长助理", leader: [yaoZuofang, qinChengrong, xuQinfa, xiaChanglei]},
];
