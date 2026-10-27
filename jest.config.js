module.exports = {
    preset: "react-native",
    // pnpm 把依赖展开成 node_modules/.pnpm/<pkg>@<ver>/node_modules/<pkg>/，
    // react-native 预设自带的 transformIgnorePatterns 只匹配 node_modules/react-native/ 这一层，
    // 于是 RN 的 jest/setup.js 命中忽略规则、不被 babel 转译，
    // 整个测试套件直接报 "Cannot use import statement outside a module" 跑不起来。
    // 这里补上 .pnpm 这一跳：先允许 .pnpm/<任意包名>/node_modules/ 前缀，再匹配 RN 系包。
    transformIgnorePatterns: [
        "node_modules/(?!(?:\\.pnpm/[^/]+/node_modules/)?((jest-)?react-native|@react-native(-community)?)/)",
    ],
    // 根目录 test.ts 是手动运行的空闲教室冒烟脚本（npx tsx test.ts），不是 Jest 用例；
    // 默认 testMatch 会把它当成测试文件，导致 npm test 报 "must contain at least one test"。
    testPathIgnorePatterns: ["/node_modules/", "<rootDir>/test.ts"],
};
