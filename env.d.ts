// 防止import SQL报错
declare module "*.sql" {
    const content: string;
    export default content;
}
