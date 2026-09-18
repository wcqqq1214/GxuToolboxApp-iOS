/**
 * 文件系统 API 通用响应包装
 * @template T - result 字段的具体类型
 */
export interface FileSystemApiRes<T = unknown> {
    /** 响应状态码，200 为成功 */
    code: number;
    /** 响应类型标签，如 "success" */
    type: string;
    /** 响应消息 */
    message: string;
    /** 响应结果数据 */
    result: T;
    /** 扩展字段 */
    extras: unknown;
    /** 响应时间（yyyy-MM-dd HH:mm:ss） */
    time: string;
    /** 接口耗时（毫秒） */
    elapsed: string;
}

/**
 * 文件列表分页结果
 * @template T - items 中每条记录的类型
 */
export interface FileListPageResult<T> {
    /** 当前页码 */
    page: number;
    /** 每页记录数 */
    pageSize: number;
    /** 总记录数 */
    total: number;
    /** 总页数 */
    totalPages: number;
    /** 当前页记录列表 */
    items: T[];
    /** 是否有上一页 */
    hasPrevPage: boolean;
    /** 是否有下一页 */
    hasNextPage: boolean;
}

/**
 * OA 文件条目
 */
export interface FileItem {
    /** 文件主键 ID */
    id: number;
    /** 文件名称 */
    fileName: string;
    /** 文件编号（如 "西大党〔2026〕27号"） */
    fileNum: string;
    /** 文件类型编码 */
    fileType: number;
    /** 文件类型名称（如 "党委文件"） */
    typeName: string;
    /** 是否显示封面 */
    isShowFront: boolean;
    /** 文件发布时间（yyyy-MM-dd HH:mm:ss） */
    showTime: string;
    /** 是否紧急 */
    isUrgent: boolean;
    /** 当前用户是否已读 */
    isRead: boolean;
    /** 是否为新建文件 */
    isNew: boolean;
    /** 上传用户身份证号 */
    upUserCard: string;
    /** 部门名称 */
    deptName: string;
    /** 阅读次数 */
    readingCount: number;
    /** 文件查看页面 URL */
    viewUrl: string;
    /** 文件正文内容（通常为 null，按需加载） */
    fileBody: string | null;
    /** PDF 文件 URL */
    pdfUrl: string | null;
    /** HTML 内容 */
    htmlContent: string | null;
    /** 附件信息 */
    attachments: unknown;
    /** 是否涉密 */
    isLevel: boolean;
    /** 涉密信息 */
    levelInfo: unknown;
    /** 是否指定用户可见 */
    isUser: boolean;
    /** 指定用户身份证信息 */
    cardInfo: unknown;
    /** 是否指定部门可见 */
    isDept: boolean;
    /** 指定部门信息 */
    deptInfo: unknown;
    /** 是否指定职务可见 */
    isTitle: boolean;
    /** 指定职务信息 */
    titleInfo: unknown;
    /** 申请信息（暂不明确） */
    sq: string | null;
    /** 会议主题 */
    huiYiZhuTi: string | null;
    /** 会议时间 */
    huiYiShiJian: string | null;
    /** 会议地点 */
    huiYiDiDian: string | null;
    /** 参会人员 */
    canHuiRenYuan: string | null;
    /** 是否需要反馈 */
    isNeedFeedback: boolean;
    /** 会议状态（暂不明确具体含义） */
    huiYiStop: unknown;
    /** 是否重点/重大文件 */
    isZd: boolean;
    /** 重点文件截止日期（yyyy-MM-dd HH:mm:ss） */
    zdJzRq: string;
    /** 是否为旧文件 */
    isOld: boolean;
    /** 是否为遗留文件 */
    isLegacy: boolean;
    /** 是否需要查看回执 */
    viewReceipt: boolean;
    /** 是否需要填写回执 */
    fillReceipt: boolean;
    /** 截止日期（备用字段） */
    zdjzrq: string | null;
    /** DOCX 文件 URL */
    docxUrl: string | null;
}


export interface LoginResult {
    /** JWT 访问令牌 */
    accessToken: string;
    /** JWT 刷新令牌（accessToken 过期后用于换新） */
    refreshToken: string;
    /** 是否需要选择组织 */
    needSelectOrg: boolean;
    /** 可选组织列表 */
    orgList: unknown;
    /** 是否需要修改密码 */
    needChangePassword: boolean;
}



/**
 * OA 文件搜索接口响应类型
 */
export interface SearchFileRes {
    code: number;
    elapsed: string;
    extras: null | unknown;
    message: string;
    result: FileListPageResult<SearchFileItem>[];
    time: string;
    type: string;
}

/**
 * 搜索接口的文件条目
 */
export interface SearchFileItem {
    /** 评论内容 */
    comment: unknown | null;

    /** 联系人姓名 */
    contactPerson: unknown | null;

    /** 联系人电话/手机号 */
    contactPhone: unknown | null;

    /** 内容摘要/预览片段*/
    contentSnippet: unknown | null;

    /** 所属部门/机构 */
    department: string;

    /** 文档生成/创建时间*/
    docTime: string;

    /** 文件编号/序号 */
    fileNum: string;

    /** 文件编码 */
    fileNumber: string;

    /** 文件类型 */
    fileType: number;

    /** 流程状态 */
    flowStatus: unknown | null;

    /** 记录唯一标识ID */
    id: number;

    /** 是否在前台显示 */
    isShowFront: boolean;

    /** 是否紧急标记 */
    isUrgent: boolean;

    /** 是否部门级紧急 */
    isUrgentDept: boolean;

    /** 脱敏状态 */
    mskState: unknown | null;

    /** 来源名称 */
    sourceName: string;

    /** 来源类型 */
    sourceType: string;

    /** 文档标题/名称 */
    title: string;

    /** 文档类型名称 */
    typeName: string;
}
