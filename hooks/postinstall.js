const xcode = require('xcode');
const path = require('path');
const semver = require('semver');
const fs = require("fs");
module.exports = context => {
    const projectRoot = context.opts.projectRoot;
    if ((context.hook === 'after_platform_add' && context.cmdLine.includes('platform add')) ||
        (context.hook === 'after_prepare' && context.cmdLine.includes('prepare')) ||
        (context.hook === 'after_plugin_add' && context.cmdLine.includes('plugin add'))) {
        // patch xcode
        patchXcode(projectRoot)
        // patch android build.gradle
        patchGradle(projectRoot)
    }
}
function patchGradle(projectRoot) {
    const platformPath = path.join(projectRoot, 'platforms', 'android');
    const appGradlePath = path.join(platformPath, 'app','build.gradle');
    try {
        fs.accessSync(appGradlePath)
        const buildGradle = fs.readFileSync(appGradlePath, "utf8");
        
        fs.writeFileSync(appGradlePath,buildGradle.replace(/apply plugin: 'kotlin-android-extensions'/g,""))
    } catch (e) {
        
    }
}
function patchXcode(projectRoot) {
    
    const platformPath = path.join(projectRoot, 'platforms', 'ios');
    // const config = getConfigParser(context, path.join(projectRoot, 'config.xml'));
    // const projectName = config.name();
    const pbxprojPath = path.join(platformPath,'Pods', 'Pods.xcodeproj', 'project.pbxproj');
    try {
        fs.accessSync(pbxprojPath)
        const xcodeProject = xcode.project(pbxprojPath);
        const COMMENT_KEY = /_comment$/;
        xcodeProject.parseSync();
        buildConfigs = xcodeProject.pbxXCBuildConfigurationSection();

        for (configName in buildConfigs) {
            if (!COMMENT_KEY.test(configName)) {
                buildConfig = buildConfigs[configName];
                xcodeProject.updateBuildProperty('BUILD_LIBRARY_FOR_DISTRIBUTION', "YES", buildConfig.name);
            }
        }
        fs.writeFileSync(pbxprojPath, xcodeProject.writeSync())
    } catch (e) {

    }
    
}
const getConfigParser = (context, configPath) => {
    let ConfigParser;
  
    if (semver.lt(context.opts.cordova.version, '5.4.0')) {
      ConfigParser = context.requireCordovaModule('cordova-lib/src/ConfigParser/ConfigParser');
    } else {
      ConfigParser = context.requireCordovaModule('cordova-common/src/ConfigParser/ConfigParser');
    }
  
    return new ConfigParser(configPath);
  };
  
const getPlatformVersionsFromFileSystem = (context, projectRoot) => {
    const cordovaUtil = context.requireCordovaModule('cordova-lib/src/cordova/util');
    const platformsOnFs = cordovaUtil.listPlatforms(projectRoot);
    const platformVersions = platformsOnFs.map(platform => {
        const script = path.join(projectRoot, 'platforms', platform, 'cordova', 'version');
        return new Promise((resolve, reject) => {
            childProcess.exec('"' + script + '"', {}, (error, stdout, _) => {
                if (error) {
                    reject(error);
                    return;
                }
                resolve(stdout.trim());
            });
        }).then(result => {
            const version = result.replace(/\r?\n|\r/g, '');
            return { platform, version };
        }, (error) => {
            console.log(error);
            process.exit(1);
        });
    });

    return Promise.all(platformVersions);
};