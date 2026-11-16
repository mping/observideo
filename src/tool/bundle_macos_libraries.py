#!/usr/bin/env python3
"""Bundle Mach-O dependencies and reject runtime links outside an app."""

import argparse
from collections import deque
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True,
                                   stderr=subprocess.STDOUT)


def load_commands(binary):
    identity, dependencies, rpaths = None, [], []
    command = None
    for line in run('otool', '-l', binary).splitlines():
        if line.strip().startswith('cmd '):
            command = line.strip().split()[1]
        match = re.match(r'\s*(?:name|path) (.*) \(offset \d+\)$', line)
        if not match:
            continue
        value = match[1]
        if command == 'LC_ID_DYLIB':
            identity = value
        elif command == 'LC_RPATH':
            rpaths.append(value)
        elif command in ('LC_LOAD_DYLIB', 'LC_LOAD_WEAK_DYLIB',
                         'LC_REEXPORT_DYLIB', 'LC_LOAD_UPWARD_DYLIB'):
            dependencies.append(value)
    return identity, dependencies, rpaths


def is_system(path):
    return path.startswith(('/usr/lib/', '/System/Library/'))


def runtime_dependencies(binary):
    # Homebrew's SDL2 may be sdl2-compat. It dlopens SDL3 instead of linking
    # it, so this dependency is absent from LC_LOAD_DYLIB / otool -L.
    if (binary.name.startswith('libSDL2')
            and b'Failed loading SDL3 library.' in binary.read_bytes()):
        return ['@loader_path/libSDL3.dylib']
    return []


def expand(path, loader, executable):
    return Path(path.replace('@loader_path', str(loader.parent))
                .replace('@executable_path', str(executable)))


def resolve(dependency, loader, executable, rpaths, search):
    if dependency.startswith('@rpath/'):
        suffix = dependency[len('@rpath/'):]
        candidates = [expand(p, loader, executable) / suffix for p in rpaths]
        candidates += [p / suffix for p in search]
    else:
        candidates = [expand(dependency, loader, executable)]
    # Cached controlled builds may retain their original build prefix. Only
    # accept the identical library filename in an explicitly supplied directory.
    candidates += [p / Path(dependency).name for p in search]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise RuntimeError(f'{loader}: missing dependency {dependency}')


def macho_files(root):
    magic = {bytes.fromhex(s) for s in ('feedface', 'cefaedfe', 'feedfacf',
                                      'cffaedfe', 'cafebabe', 'bebafeca',
                                      'cafebabf', 'bfbafeca')}
    for path in root.rglob('*'):
        if path.is_file() and not path.is_symlink():
            with path.open('rb') as stream:
                if stream.read(4) in magic:
                    yield path.resolve()


def bundle(roots, destination, search, executable, rpath=False):
    destination.mkdir(parents=True, exist_ok=True)
    destination = destination.resolve()
    search = [destination, *[p.resolve() for p in search]]
    queue = deque((path.resolve(), path.resolve()) for path in roots)
    visited, origins = set(), {}
    count = 0
    while queue:
        binary, source = queue.popleft()
        if binary in visited:
            continue
        visited.add(binary)
        identity, dependencies, rpaths = load_commands(source)
        dynamic = runtime_dependencies(source)
        changes = []
        for dependency in dependencies + dynamic:
            if is_system(dependency):
                continue
            try:
                resolved = resolve(dependency, source, executable, rpaths, search)
            except RuntimeError:
                if dependency not in dynamic:
                    raise
                libdir = Path(run('pkg-config', '--variable=libdir', 'sdl3').strip())
                resolved = resolve(dependency, source, executable, rpaths, [libdir])
            # Preserve frameworks and libraries already embedded by Xcode.
            if resolved in visited or resolved.is_relative_to(destination):
                target = resolved
            else:
                target = destination / Path(dependency).name
                previous = origins.get(target)
                if previous is not None and previous != resolved:
                    raise RuntimeError(f'Conflicting libraries for {target}: '
                                       f'{previous} and {resolved}')
                origins[target] = resolved
                if not target.exists():
                    shutil.copy2(resolved, target)
                    count += 1
            if target not in visited:
                queue.append((target, resolved))
            relative = ('@rpath/' + str(target.relative_to(destination)) if rpath else
                        '@loader_path/' + os.path.relpath(target, binary.parent))
            if (rpath and dependency.startswith('@rpath/')
                    and resolved.is_relative_to(destination)):
                # Retain working framework references: growing every load command
                # can exhaust the executable's reserved Mach-O header space.
                relative = dependency
            if dependency not in dynamic and relative != dependency:
                changes += ['-change', dependency, relative]
        if identity and binary.parent == destination:
            changes += ['-id', '@rpath/' + binary.name]
        if changes:
            binary.chmod(binary.stat().st_mode | stat.S_IWUSR)
            run('install_name_tool', *changes, binary)
            run('codesign', '--force', '--sign', '-', binary)
    print(f'Bundled {count} libraries; processed {len(visited)} Mach-O files.')


def check_app(app):
    app = app.resolve()
    binaries = list(macho_files(app))
    executable = app / 'Contents/MacOS'
    with (app / 'Contents/Info.plist').open('rb') as stream:
        main = executable / plistlib.load(stream)['CFBundleExecutable']
    # Check each executable independently. ffprobe cannot inherit the Flutter
    # executable's rpaths when it is launched as a separate process.
    executables = [p for p in binaries if is_executable(p)]
    executables.sort(key=lambda p: p != main)
    checked = set()
    for entry in [*executables, *binaries]:
        if entry in checked and entry not in executables:
            continue
        visited = set()
        queue = deque([(entry, [], entry.parent if entry in executables else executable)])
        while queue:
            binary, inherited, executable_dir = queue.popleft()
            if binary in visited:
                continue
            visited.add(binary)
            checked.add(binary)
            _, dependencies, rpaths = load_commands(binary)
            dependencies += runtime_dependencies(binary)
            paths = [str(expand(p, binary, executable_dir)) for p in rpaths] + inherited
            for dependency in dependencies:
                if is_system(dependency):
                    continue
                if dependency.startswith('/'):
                    raise RuntimeError(f'{binary}: absolute runtime dependency {dependency}')
                resolved = resolve(dependency, binary, executable_dir, paths, [])
                if not resolved.is_relative_to(app):
                    raise RuntimeError(f'{binary}: dependency escapes app: {dependency}')
                queue.append((resolved, paths, executable_dir))
    print(f'Validated {len(binaries)} Mach-O files: all dependencies are bundled or system libraries.')


def is_executable(binary):
    return 'EXECUTE' in run('otool', '-hv', binary).split()


def bundle_app(app, search):
    app = app.resolve()
    destination = app / 'Contents/Frameworks'
    binaries = list(macho_files(app))
    # Shorten absolute build-host references first, freeing header space before
    # adding the helper executable's run path.
    bundle(binaries, destination, search, app / 'Contents/MacOS', rpath=True)
    for binary in binaries:
        if is_executable(binary):
            rpaths = load_commands(binary)[2]
            if not any(expand(p, binary, binary.parent).resolve() == destination for p in rpaths):
                path = '@loader_path/' + os.path.relpath(destination, binary.parent)
                run('install_name_tool', '-add_rpath', path, binary)
                run('codesign', '--force', '--sign', '-', binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--libraries', type=Path)
    parser.add_argument('--rpath', action='store_true',
                        help='Use @rpath references for CocoaPods staging.')
    parser.add_argument('--binary', action='append', type=Path, default=[])
    parser.add_argument('--search', action='append', type=Path, default=[])
    args = parser.parse_args()
    if args.app:
        if not args.check:
            bundle_app(args.app, args.search)
        check_app(args.app)
    elif args.libraries and args.binary and not args.check:
        bundle(args.binary + list(args.libraries.glob('*.dylib')),
               args.libraries, args.search, Path.cwd(), rpath=args.rpath)
    else:
        parser.error('Specify --app, or --libraries and --binary.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(getattr(error, 'output', None) or str(error), file=sys.stderr)
        sys.exit(1)
