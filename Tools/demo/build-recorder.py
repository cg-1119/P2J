#!/usr/bin/env python3
"""화면 기록 권한을 개별 승인할 수 있는 촬영 도구 앱을 빌드합니다."""
from pathlib import Path
import plistlib
import subprocess

root = Path(__file__).resolve().parents[2]
app = root/'.build/demo.noindex/P2J Demo Recorder.app'
contents = app/'Contents'
(contents/'MacOS').mkdir(parents=True, exist_ok=True)
with (contents/'Info.plist').open('wb') as f:
    plistlib.dump({'CFBundleExecutable':'record','CFBundleIdentifier':'com.cg1119.p2j.demo-recorder',
                  'CFBundleName':'P2J Demo Recorder','CFBundlePackageType':'APPL','LSUIElement':True},f)
subprocess.run(['xcrun','swiftc','-parse-as-library',str(root/'Tools/demo/record.swift'),
                str(root/'Tools/demo/RecorderApp.swift'),'-o',str(contents/'MacOS/record')],check=True)
subprocess.run(['codesign','--force','--sign','-','--identifier','com.cg1119.p2j.demo-recorder',str(app)],check=True)
print(app)
print('앱을 직접 실행하고 화면 기록 권한을 허용하세요. 재빌드하면 권한 갱신이 필요할 수 있습니다.')
