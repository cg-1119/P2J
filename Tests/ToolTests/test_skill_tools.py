import contextlib
import io
import json
import pathlib
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
CLIENT = ROOT/'Skills/p2j-control/scripts/p2j'
INSTALLER = ROOT/'Tools/install-skill'

class SkillToolsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = pathlib.Path(self.temp.name)
        self.response = self.home/'data/automation'
        self.response.mkdir(parents=True)
        (self.response.parent/'automation-token').write_text('SECRET-NOT-FOR-OUTPUT')

    def invoke(self, *args, stdin=''):
        out = io.StringIO()
        with patch.object(sys,'argv',[str(CLIENT),*args]), patch.object(sys,'stdin',io.StringIO(stdin)), contextlib.redirect_stdout(out):
            code = runpy.run_path(str(CLIENT))['main']()
        return code,json.loads(out.getvalue())

    def test_stdin_preserves_quotes_shell_text_and_unicode_without_execution(self):
        title = '영어 공부 "30분" $(touch /tmp/do-not-run) `echo nope`'
        with patch('subprocess.run') as launch:
            code,reply = self.invoke('add','--json','-','--dry-run',stdin=json.dumps({'title':title}))
        self.assertEqual(code,0)
        self.assertEqual(reply['title'],title)
        self.assertNotIn('token',reply)
        launch.assert_not_called()

    def test_unknown_fields_rejected_instead_of_silently_ignored(self):
        with self.assertRaises(ValueError):
            self.invoke('update','--dry-run','--json','{"taskID":"x","subtasks":["ignored"]}')

    def test_doctor_does_not_reveal_token_or_launch_app(self):
        with patch('subprocess.run') as launch:
            code,reply = self.invoke('doctor','--response-dir',str(self.response))
        self.assertEqual(code,0)
        self.assertEqual(reply['data']['tokenStoresFound'],1)
        self.assertNotIn('SECRET',json.dumps(reply))
        launch.assert_not_called()

    def test_environment_paths_used_by_installed_copy(self):
        app = self.home/'P2J.app'; app.mkdir()
        with patch.dict('os.environ',{'P2J_APP':str(app),'P2J_RESPONSE_DIR':str(self.response)}):
            code,reply = self.invoke('doctor')
        self.assertEqual(code,0)
        self.assertEqual(pathlib.Path(reply['data']['app']),app.resolve())

    def test_launch_error_does_not_expose_url_or_token(self):
        error = subprocess.CalledProcessError(1,['open','p2j://automation?SECRET-NOT-FOR-OUTPUT'])
        with patch('subprocess.run',side_effect=error):
            with self.assertRaises(ValueError) as caught:
                self.invoke('list','--response-dir',str(self.response))
        self.assertNotIn('SECRET',str(caught.exception))
        self.assertNotIn('p2j://',str(caught.exception))

    def test_cached_retry_returns_same_result_without_launching(self):
        rid = '11111111-1111-4111-8111-111111111111'
        expected = {'id':rid,'ok':True,'data':{'title':'중복 방지'}}
        (self.response/(rid+'.json')).write_text(json.dumps(expected))
        with patch('subprocess.run') as launch:
            code,reply = self.invoke('add','--json','{"title":"중복 방지"}','--request-id',rid,'--response-dir',str(self.response))
        self.assertEqual((code,reply),(0,expected))
        launch.assert_not_called()

    def test_timeout_returns_request_id_for_retry(self):
        rid = '22222222-2222-4222-8222-222222222222'
        with patch('subprocess.run'):
            code,reply = self.invoke('list','--request-id',rid,'--response-dir',str(self.response),'--timeout','0.001')
        self.assertEqual(code,1)
        self.assertEqual(reply['id'],rid)
        self.assertFalse(reply['ok'])

    def test_personal_install_is_self_contained_and_replacement_backs_up(self):
        install = runpy.run_path(str(INSTALLER))['install']
        parent = self.home/'.claude/skills'
        with contextlib.redirect_stdout(io.StringIO()):
            target = install(ROOT/'Skills/p2j-control', parent)
            self.assertTrue((target/'references/commands.md').is_file())
            command = [sys.executable,str(target/'scripts/p2j'),'list','--dry-run']
            reply = subprocess.run(command,cwd=self.home,capture_output=True,text=True,check=True)
            self.assertEqual(json.loads(reply.stdout)['operation'],'list')
            with self.assertRaises(ValueError):install(ROOT/'Skills/p2j-control',parent)
            (target/'local-note.txt').write_text('preserve me')
            install(ROOT/'Skills/p2j-control',parent,replace=True)
        backups = list((parent.parent/'p2j-skill-backups').glob('*/local-note.txt'))
        self.assertEqual(len(backups),1)
        self.assertEqual(backups[0].read_text(),'preserve me')

if __name__ == '__main__':unittest.main()
