/** 这里是新的后端的数据类型 */
export interface ApiResponse<T = any> {
    code: number;
    data: T;
    message: string;
}

export interface PageData<T> {
    totalCount: number;
    totalPage: number;
    currentPage: number;
    items: T[];
}
