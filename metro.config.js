const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');
const path = require('path');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
    resolver: {
        resolveRequest: (context, moduleName, platform) => {
            if (moduleName === 'cheerio') {
                return {
                    filePath: path.resolve(__dirname, 'node_modules/react-native-cheerio/index.js'),
                    type: 'sourceFile',
                };
            }
            return context.resolveRequest(context, moduleName, platform);
        },
    },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
