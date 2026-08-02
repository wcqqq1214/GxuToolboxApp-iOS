This is a new [**React Native**](https://reactnative.dev) project, bootstrapped using [`@react-native-community/cli`](https://github.com/react-native-community/cli).

## 常用文档
- [RN doc](https://reactnative.dev/docs/components-and-apis)
- [react native elements ui](https://reactnativeelements.com/docs/customizing)
- [icon](https://oblador.github.io/react-native-vector-icons/)
- [react navigation](https://reactnavigation.org/docs/getting-started/)
- [RN库市场](https://reactnative.directory/)
- [moment](https://momentjs.com/docs/)
- []()

# Getting Started

> **Note**: Make sure you have completed the [Set Up Your Environment](https://reactnative.dev/docs/set-up-your-environment) guide before proceeding.

## Step 1: Start Metro

First, you will need to run **Metro**, the JavaScript build tool for React Native.

To start the Metro dev server, run the following command from the root of your React Native project:

```sh
# Using npm
npm start

# OR using Yarn
yarn start
```

## Step 2: Build and run your app

With Metro running, open a new terminal window/pane from the root of your React Native project, and use one of the following commands to build and run your Android or iOS app:

### Android

```sh
# Using npm
npm run android

# OR using Yarn
yarn android
```

### iOS

For iOS, remember to install CocoaPods dependencies (this only needs to be run on first clone or after updating native deps).

The first time you create a new project, run the Ruby bundler to install CocoaPods itself:

```sh
bundle install
```

Then, and every time you update your native dependencies, run:

```sh
bundle exec pod install
```

For more information, please visit [CocoaPods Getting Started guide](https://guides.cocoapods.org/using/getting-started.html).

```sh
# Using npm
npm run ios

# OR using Yarn
yarn ios
```

If everything is set up correctly, you should see your new app running in the Android Emulator, iOS Simulator, or your connected device.

This is one way to run your app — you can also build it directly from Android Studio or Xcode.

## Step 3: Modify your app

Now that you have successfully run the app, let's make changes!

Open `App.tsx` in your text editor of choice and make some changes. When you save, your app will automatically update and reflect these changes — this is powered by [Fast Refresh](https://reactnative.dev/docs/fast-refresh).

When you want to forcefully reload, for example to reset the state of your app, you can perform a full reload:

- **Android**: Press the <kbd>R</kbd> key twice or select **"Reload"** from the **Dev Menu**, accessed via <kbd>Ctrl</kbd> + <kbd>M</kbd> (Windows/Linux) or <kbd>Cmd ⌘</kbd> + <kbd>M</kbd> (macOS).
- **iOS**: Press <kbd>R</kbd> in iOS Simulator.

## Congratulations! :tada:

You've successfully run and modified your React Native App. :partying_face:

### Now what?

- If you want to add this new React Native code to an existing application, check out the [Integration guide](https://reactnative.dev/docs/integration-with-existing-apps).
- If you're curious to learn more about React Native, check out the [docs](https://reactnative.dev/docs/getting-started).

# Troubleshooting

If you're having issues getting the above steps to work, see the [Troubleshooting](https://reactnative.dev/docs/troubleshooting) page.

# Learn More

To learn more about React Native, take a look at the following resources:

- [React Native Website](https://reactnative.dev) - learn more about React Native.
- [Getting Started](https://reactnative.dev/docs/environment-setup) - an **overview** of React Native and how setup your environment.
- [Learn the Basics](https://reactnative.dev/docs/getting-started) - a **guided tour** of the React Native **basics**.
- [Blog](https://reactnative.dev/blog) - read the latest official React Native **Blog** posts.
- [`@facebook/react-native`](https://github.com/facebook/react-native) - the Open Source; GitHub **repository** for React Native.

### 项目结构说明

本项目是一个使用 React Native 构建的跨平台移动应用。以下是项目根目录下主要文件和文件夹的用途说明：

*   `android/`: 包含原生 Android 项目的所有文件。如果您需要进行 Android 平台的特定配置或编写原生模块，将会在此目录下操作。
*   `ios/`: 包含原生 iOS 项目的所有文件（Xcode 项目）。如果您需要进行 iOS 平台的特定配置或编写原生模块，将会在此目录下操作。
*   `src/`: 存放应用的所有源代码，包括组件（Components）、页面（Screens）、状态管理（State Management）、工具函数（Utils）等。这是项目开发的主要工作目录。
*   `node_modules/`: 存放项目的所有第三方依赖库。这个目录由 `npm` 或 `yarn` 自动管理，通常不直接修改。
*   `__tests__/`: 包含应用的单元测试和集成测试文件。项目使用 Jest 作为测试框架。
*   `App.tsx`: 应用的根组件，是整个 React Native 应用的入口界面。
*   `index.js`: React Native 应用的注册入口文件。它使用 `AppRegistry` 来注册根组件 `App.tsx`，是应用的启动点。
*   `package.json`: 定义了项目的基本信息、依赖库、以及可执行的脚本命令（如 `npm start`, `npm test` 等）。
*   `yarn.lock` 或 `package-lock.json`: 锁定项目依赖库的确切版本，以保证团队成员和不同环境中安装的依赖版本一致。
*   `README.md`: 项目的说明文档，您现在正在阅读的就是这个文件。
*   `metro.config.js`: React Native 打包工具 Metro 的配置文件。
*   `babel.config.js`: Babel 编译器的配置文件，用于将现代 JavaScript (ES6+) 和 JSX 语法转换为兼容性更好的代码。
*   `tsconfig.json`: TypeScript 编译器的配置文件。
*   `.eslintrc.js`: ESLint 的配置文件，用于代码规范和质量检查。
*   `.prettierrc.js`: Prettier 的配置文件，用于代码格式化，保证代码风格统一。
*   `.gitignore`: 指定了 Git 版本控制系统需要忽略的文件和目录，例如 `node_modules`、`build` 产物等。
*   `app.json`: 应用的配置文件，通常包含应用名称 `displayName` 等信息。

### `src` 目录结构

`src` 目录是项目应用逻辑的核心，包含了所有的源代码。

*   `components/`: 存放可复用的 UI 组件。这些组件被设计成独立的、可组合的单元，可以在应用的不同页面中重复使用，例如按钮、输入框、卡片等。
*   `screens/`: 存放应用的各个页面或屏幕。每个文件或文件夹通常代表一个完整的用户界面，例如登录页、首页、设置页等。
*   `route/`: 包含应用的导航和路由逻辑。这里定义了页面之间的跳转关系和导航栈的结构，通常会使用像 React Navigation 这样的库。
*   `js/`: 存放通用的 JavaScript 模块和工具函数。这些函数不与特定的 UI 组件或页面绑定，可以在整个应用中被调用，例如数据处理、API 请求封装等。
*   `type/`: 存放 TypeScript 的类型定义（interfaces and types）。通过在这里集中管理类型，可以提高代码的可维护性和类型安全性。

#### `components` - 可复用组件

此目录存放了应用中可以被多个页面复用的UI组件。

-   `CheckUpdate.tsx`: 用于检查应用是否有新版本并提示用户更新的组件。
-   `header/`: 存放页面头部相关的组件。
-   `tool/`: 存放与“工具”功能相关的可复用组件。
-   `un-ui/`: 一套自定义的UI组件库，用于构建应用的基础界面元素。

#### `js` - 通用逻辑与工具函数

此目录包含了项目通用的业务逻辑和辅助函数。

-   `color.ts`: 定义了应用的主题颜色和色彩规范。
-   `theme.ts`: 应用的主题管理，可能包括浅色模式和深色模式的切换逻辑。
-   `http.ts`: 封装了网络请求（如 `fetch` 或 `axios`），提供了统一的API调用方式和错误处理。
-   `domParser.ts`: 用于解析HTML/XML文档，可能用于爬取和解析网页数据。
-   `permission.ts`: 封装了Android和iOS平台的权限请求逻辑，如请求存储、相机权限等。
-   `DownloadAndInstallApk.ts`: 提供了在Android上下载并安装新版APK的功能。
-   `rasPassword.js`: 应该是 `rsaPassword.js` 的笔误，用于对密码等敏感信息进行RSA加密。
-   `store.ts`: 封装了本地持久化存储（如 `AsyncStorage`），用于保存用户数据或应用状态。
-   `jw/`: 存放与“教务”系统相关的逻辑。
-   `mgr/`: 存放“管理器”相关的逻辑。

#### `route` - 导航与路由

此目录定义了应用的页面导航结构。

-   `RootStack.tsx`: 应用的根导航栈，是所有页面的容器。
-   `screens/`: 定义了各个页面的路由配置。

#### `screens` - 应用页面

此目录存放了应用的各个功能页面。

-   `Root.tsx`: 应用的根页面，可能会处理一些初始化逻辑，如检查登录状态、引导页等。
-   `MainTab.tsx`: 应用的主导航栏，包含了首页、工具、设置等主要功能入口。
-   `HomeScreen.tsx`: 应用的首页。
-   `setting/`: 存放设置相关的页面。
-   `tool/`: 存放“工具”功能集合的页面。

#### `type` - TypeScript 类型定义

此目录集中管理了项目所有的TypeScript类型，以增强代码的健壮性。

-   `global.ts`: 全局通用的类型定义。
-   `api/`: 定义了与后端API交互时请求和响应的数据结构。
-   `infoQuery/`: 定义了信息查询功能相关的数据类型。
