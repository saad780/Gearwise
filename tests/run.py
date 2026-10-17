"""Run the actual addon under Lua 5.1 using a simulated WoW client: python tests/run.py."""
from pathlib import Path
from lupa import lua51

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "Gearwise"
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests" / "wow.lua").read_text(encoding="utf-8"))
loader = lua.eval("function(code, name) assert(loadstring(code, '@' .. name))('Gearwise', ns) end")
for filename in (ADDON / "Gearwise.toc").read_text().splitlines():
    if filename.endswith(".lua"):
        loader((ADDON / filename).read_text(encoding="utf-8-sig"), filename)
lua.execute((ROOT / "tests" / "scenarios.lua").read_text(encoding="utf-8"))
