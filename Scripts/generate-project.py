#!/usr/bin/env python3
"""Generate a dependency-free Xcode project; rerun when adding source files."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
project = root / 'AutoSignStore.xcodeproj'
project.mkdir(exist_ok=True)

def ident(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()

def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

objects = []
def obj(key, value):
    objects.append(f'\t\t{ident(key)} = {{ {value} }};')
    return ident(key)

sources = sorted((root / 'AutoSignStore').rglob('*.swift'))
source_builds = []
file_ids = []
for path in sources:
    rel = str(path.relative_to(root))
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(rel)}; sourceTree = SOURCE_ROOT;')
    file_ids.append(ref)
    source_builds.append(obj('build:' + rel, f'isa = PBXBuildFile; fileRef = {ref};'))
asset = obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = AutoSignStore/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
asset_build = obj('assets-build', f'isa = PBXBuildFile; fileRef = {asset};')
localized_ids, localized_builds = [], []
localized_files = {}
for path in sorted((root / 'AutoSignStore').rglob('*.lproj/*')):
    if path.suffix in ('.strings', '.stringsdict'):
        localized_files.setdefault(path.name, []).append(path)
for name, paths in sorted(localized_files.items()):
    children = []
    for path in paths:
        rel = str(path.relative_to(root))
        language = path.parent.stem
        file_type = 'text.plist.strings' if path.suffix == '.strings' else 'text.plist.xml'
        children.append(obj(rel, f'isa = PBXFileReference; lastKnownFileType = {file_type}; name = {quote(language)}; path = {quote(rel)}; sourceTree = SOURCE_ROOT;'))
    variant = obj('localized:' + name, f'isa = PBXVariantGroup; children = (' + ','.join(children) + f',); name = {quote(name)}; sourceTree = "<group>";')
    localized_ids.append(variant)
    localized_builds.append(obj('localized-build:' + name, f'isa = PBXBuildFile; fileRef = {variant};'))
info = obj('info', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = AutoSignStore/Resources/Info.plist; sourceTree = SOURCE_ROOT;')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AutoSignStore.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
group = obj('group', 'isa = PBXGroup; children = (' + ','.join(file_ids + localized_ids + [asset, info, products]) + ',); sourceTree = "<group>";')
source_phase = obj('sources', 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(source_builds) + ',); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join([asset_build] + localized_builds) + ',); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
project_configs, target_configs = [], []
for name in ('Debug', 'Release'):
    project_configs.append(obj('project-' + name, f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; }};'))
    settings = '''ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 7;
        GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = AutoSignStore/Resources/Info.plist;
        IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 1.3.0;
        PRODUCT_BUNDLE_IDENTIFIER = local.autosign.store; PRODUCT_NAME = "$(TARGET_NAME)";
        SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; TARGETED_DEVICE_FAMILY = "1,2";
        SWIFT_VERSION = 6.0; SWIFT_STRICT_CONCURRENCY = complete;
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";'''
    settings += ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; DEBUG_INFORMATION_FORMAT = dwarf;' if name == 'Debug' else ' SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    target_configs.append(obj('target-' + name, f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ {settings} }};'))
project_list = obj('project-configs', 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(project_configs) + ',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_list = obj('target-configs', 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(target_configs) + ',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {target_list}; buildPhases = ({source_phase},{frameworks},{resources},); buildRules = (); dependencies = (); name = AutoSignStore; productName = AutoSignStore; productReference = {product}; productType = "com.apple.product-type.application";')
project_id = obj('project', f'isa = PBXProject; attributes = {{ LastSwiftUpdateCheck = 2700; LastUpgradeCheck = 2700; }}; buildConfigurationList = {project_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, "zh-Hans", Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project_id}; }}\n')
schemes = project / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="AutoSignStore.app" BlueprintName="AutoSignStore" ReferencedContainer="container:AutoSignStore.xcodeproj"/>'
(schemes / 'AutoSignStore.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(project)
