"""Exercise relocation with real Mach-O binaries, including indirect deps."""

import importlib.util
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'bundler', Path(__file__).resolve().parents[1] / 'bundle_macos_libraries.py')
bundler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundler)


@unittest.skipUnless(sys.platform == 'darwin', 'Requires the macOS linker')
class BundleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='observideo bundle ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.external = self.root / 'build host'
        self.external.mkdir()
        self.app = self.root / 'Observideo.app'
        self.frameworks = self.app / 'Contents/Frameworks'
        self.executables = self.app / 'Contents/MacOS'
        self.frameworks.mkdir(parents=True)
        self.executables.mkdir()
        with (self.app / 'Contents/Info.plist').open('wb') as stream:
            plistlib.dump({'CFBundleExecutable': 'observideo'}, stream)
        self.leaf = self.external / 'libLeaf.dylib'
        self.parent = self.external / 'libParent.dylib'
        self.compile('int leaf(void) { return 42; }', self.leaf,
                     '-dynamiclib', '-Wl,-install_name,' + str(self.leaf))
        self.compile('extern int leaf(void); int parent(void) { return leaf(); }',
                     self.parent, '-dynamiclib', str(self.leaf),
                     '-Wl,-install_name,' + str(self.parent))
        self.main = self.executables / 'observideo'
        self.compile('extern int parent(void); int main(void) { return parent() != 42; }',
                     self.main, str(self.parent),
                     '-Wl,-rpath,@executable_path/../Frameworks')

    def compile(self, source, output, *flags):
        subprocess.run(['cc', '-x', 'c', '-', '-x', 'none', '-o', str(output), *flags],
                       input=source, text=True, check=True, capture_output=True)

    def test_transitive_libraries_work_without_build_host(self):
        helper = self.executables / 'media/bin/ffprobe'
        helper.parent.mkdir(parents=True)
        self.compile('extern int parent(void); int main(void) { return parent() != 42; }',
                     helper, str(self.parent))
        bundler.bundle_app(self.app, [])
        self.external.rename(self.root / 'unavailable')
        bundler.check_app(self.app)
        subprocess.run([str(self.main)], check=True)
        subprocess.run([str(helper)], check=True)

    def test_staged_rpath_libraries_and_relocated_cached_prefix(self):
        stage = self.root / 'staged'
        libs = stage / 'Libraries'
        libs.mkdir(parents=True)
        mpv = stage / 'Mpv'
        shutil.copy2(self.parent, mpv)
        # A cached prefix has moved since the library was compiled.
        moved = self.root / 'moved prefix'
        self.external.rename(moved)
        bundler.bundle([mpv], libs, [moved], self.executables, rpath=True)
        shutil.copy2(mpv, self.frameworks / self.parent.name)
        shutil.copytree(libs, self.frameworks, dirs_exist_ok=True)
        bundler.bundle_app(self.app, [moved])
        moved.rename(self.root / 'unavailable')
        bundler.check_app(self.app)
        subprocess.run([str(self.main)], check=True)

    def test_rejects_external_or_missing_dependency(self):
        with self.assertRaisesRegex(RuntimeError, 'absolute runtime dependency'):
            bundler.check_app(self.app)
        self.leaf.unlink()
        with self.assertRaisesRegex(RuntimeError, 'missing dependency'):
            bundler.bundle([self.main], self.frameworks, [], self.executables)

    def test_preserves_versioned_framework_load_commands(self):
        # Reproduce the tiny CocoaPods shim that failed on the CI runner.
        mpv = self.frameworks / 'Mpv.framework/Versions/A/Mpv'
        shim_name = 'media_kit_libs_macos_video'
        shim = self.frameworks / f'{shim_name}.framework/Versions/A/{shim_name}'
        for binary in (mpv, shim):
            binary.parent.mkdir(parents=True)
            (binary.parents[2] / binary.name).symlink_to('Versions/A/' + binary.name)
        self.compile('int mpv(void) { return 42; }', mpv, '-dynamiclib',
                     '-Wl,-install_name,@rpath/Mpv.framework/Mpv')
        shim_id = f'@rpath/{shim_name}.framework/Versions/A/{shim_name}'
        self.compile('extern int mpv(void); int parent(void) { return mpv(); }',
                     shim, '-dynamiclib', str(mpv), '-Wl,-install_name,' + shim_id)
        self.compile('extern int parent(void); int main(void) { return parent() != 42; }',
                     self.main, str(shim), '-Wl,-rpath,@executable_path/../Frameworks')
        original = {p: p.read_bytes() for p in (mpv, shim, self.main)}
        bundler.bundle_app(self.app, [])
        for binary, content in original.items():
            self.assertEqual(binary.read_bytes(), content,
                             f'Already relocatable binary was rewritten: {binary}')
        bundler.check_app(self.app)
        subprocess.run([str(self.main)], check=True)

    def test_sdl_compat_runtime_dependency(self):
        compat = self.external / 'libSDL2-2.0.0.dylib'
        shutil.copy2(self.leaf, self.external / 'libSDL3.dylib')
        self.compile('''
            #include <dlfcn.h>
            const char marker[] = "Failed loading SDL3 library.";
            int parent(void) {
                void *h = dlopen("@loader_path/libSDL3.dylib", RTLD_NOW);
                if (!h) return 0;
                return ((int (*)(void))dlsym(h, "leaf"))();
            }
        ''', compat, '-dynamiclib', '-Wl,-install_name,' + str(compat))
        self.compile('extern int parent(void); int main(void) { return parent() != 42; }',
                     self.main, str(compat), '-Wl,-rpath,@executable_path/../Frameworks')
        bundler.bundle_app(self.app, [self.external])
        self.external.rename(self.root / 'unavailable')
        bundler.check_app(self.app)
        subprocess.run([str(self.main)], check=True)
        (self.frameworks / 'libSDL3.dylib').unlink()
        with self.assertRaisesRegex(RuntimeError, 'missing dependency'):
            bundler.check_app(self.app)


if __name__ == '__main__':
    unittest.main()
