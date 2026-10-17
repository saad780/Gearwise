"""Load the addon as the game does, then test its decisions and UI integration."""
from pathlib import Path
import subprocess
import sys
from lupa.lua51 import LuaRuntime
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("io.stdout:setvbuf('no')")
    lua.execute((ROOT / "tests" / "wowmock.lua").read_text(encoding="utf-8"))
    load = lua.eval("""function(source, path, ns)
        local chunk, err = loadstring(source, '@' .. path)
        if not chunk then error(err) end
        chunk('Gearwise', ns)
    end""")
    ns = lua.table()
    for line in (ROOT / "Gearwise" / "Gearwise.toc").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            load((ROOT / "Gearwise" / line).read_text(encoding="utf-8"), line, ns)
    lua.execute('mock.Fire("ADDON_LOADED", "Gearwise"); mock.Fire("PLAYER_LOGIN")')
    failures = lua.execute((ROOT / "tests" / "test_gearwise.lua").read_text(encoding="utf-8"))
    for filename in ("Upgrade.tga", "Downgrade.tga"):
        with Image.open(ROOT / "Gearwise" / "Media" / filename) as icon:
            assert icon.size == (32, 32) and icon.mode == "RGBA", f"Invalid WoW texture: {filename}"
            assert icon.getpixel((0, 0))[3] == 0, f"Icon background is not transparent: {filename}"
            icon.verify()
    for path in (ROOT / "Gearwise").glob("*.lua"):
        assert not path.read_bytes().startswith(b"\xef\xbb\xbf"), f"Unexpected BOM: {path}"
    print("TOC, Lua 5.1 loading, transparent TGA textures, and source encoding verified.")
    if failures:
        return True
    return subprocess.run([sys.executable, str(ROOT / "tests" / "run.py")]).returncode != 0


if __name__ == "__main__":
    sys.exit(main())
