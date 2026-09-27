#!/usr/bin/env python3
"""현재 앱 UI를 사용하는 격리된 촬영용 빌드. 개인 저장소·위젯은 사용하지 않습니다."""
import pathlib, plistlib, shutil, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / '.build' / 'demo.noindex'
OUT.mkdir(parents=True, exist_ok=True)
sources = OUT / 'Sources'
sources.mkdir(exist_ok=True)
for folder in ['Shared', 'TODOFirst']:
    shutil.copytree(ROOT / folder, sources / folder, dirs_exist_ok=True)
p = sources / 'Shared/Tasks/TaskRepository.swift'
s = p.read_text(); start = s.index('        let directory =', s.index('static func local'))
end = s.index('\n    }', start)
s = s[:start] + '        return Self(fileURL: URL(fileURLWithPath: ' + __import__('json').dumps(str(OUT / 'data/tasks.json')) + '))' + s[end:]
p.write_text(s)
p = sources / 'TODOFirst/App/TODOFirstApp.swift'; s = p.read_text()
s = s.replace('private var hasCompletedTutorial = false', 'private var hasCompletedTutorial = true')
s = s.replace('TaskStore(preferences: .standard, didChange: { sync.publish($0) })', 'TaskStore(preferences: .standard)')
s = s.replace('.defaultSize(width: 780, height: 600)', '.defaultSize(width: 920, height: 760)')
p.write_text(s)
app = OUT / 'P2JDemo.app'; contents = app / 'Contents'; binary = contents / 'MacOS/P2JDemo'
binary.parent.mkdir(parents=True, exist_ok=True)
with (contents / 'Info.plist').open('wb') as f:
    plistlib.dump({'CFBundleExecutable':'P2JDemo', 'CFBundleIdentifier':'com.cg1119.p2j.demo',
                  'CFBundleName':'P2J Demo', 'CFBundlePackageType':'APPL', 'NSHighResolutionCapable':True,
                  'CFBundleURLTypes':[{'CFBundleURLName':'P2J Demo', 'CFBundleURLSchemes':['p2j-demo']}]}, f)
# 데모 URL도 동일한 자동화 구현을 통과하도록 복사본의 scheme만 바꿉니다.
for p in [sources/'TODOFirst/App/TODOFirstApp.swift', sources/'Shared/Tasks/TaskStore.swift']:
    p.write_text(p.read_text().replace('url.scheme == "p2j"', 'url.scheme == "p2j-demo"'))
files = list((sources/'Shared/Tasks').glob('*.swift')) + list((sources/'Shared/Widgets').glob('*.swift'))
files += [sources/'Shared/AppIdentity.swift'] + list((sources/'TODOFirst/App').glob('*.swift'))
files += list((sources/'TODOFirst/Features').glob('*/*.swift'))
subprocess.run(['xcrun','swiftc','-parse-as-library','-module-cache-path',str(OUT/'module-cache'),'-o',str(binary),*map(str,files)],check=True)
print(app)
