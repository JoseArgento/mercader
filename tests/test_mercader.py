"""Mercader running in Lua 5.1 (the Lua of WoW) on a small stand-in for the client.

A test fills the vendor window (MOCK.openMerchant) and Mercader must write down exactly what is worth it,
with the stock the window reported, and draw it on the map and in the book.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

lupa = pytest.importorskip("lupa.lua51")

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "Mercader"
TESTS = Path(__file__).resolve().parent

LIZZARIK = "{ name = 'Lizzarik', npc = 3658, items = { {4778, 2, 26200}, {4777, 2, 13200}, {858, 3, 100}, {2488, -1, 500} } }"


def toc_lines():
    return [ln.strip() for ln in (ADDON / "Mercader.toc").read_text(encoding="utf-8").splitlines()]


def toc_files():
    return [ln.replace("\\", "/") for ln in toc_lines() if ln and not ln.startswith("#") and ln.endswith(".lua")]


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


class Client:
    def __init__(self, locale="enUS", saved=None, side="Alliance", where=(1413, 0.57, 0.34)):
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((TESTS / "wow_mock.lua").read_text(encoding="utf-8"))
        self.lua.execute((TESTS / "mercader_mock.lua").read_text(encoding="utf-8"))
        self.m = self.lua.globals().MOCK
        self.m.locale = locale
        self.m.player.side = side
        self.goto(*where)
        if saved is not None:
            self.lua.execute(saved)
        self.ns = self.lua.table()
        loader = self.lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")
        for rel in toc_files():
            loader((ADDON / rel).read_text(encoding="utf-8"), f"Mercader/{rel}")("Mercader", self.ns)

    def login(self):
        self.fire("ADDON_LOADED", "Mercader")
        self.fire("PLAYER_LOGIN")
        return self

    def goto(self, map_id, x=None, y=None):
        self.m.where.mapID = map_id
        self.m.where.x, self.m.where.y = x, y

    def run(self, code):
        return self.lua.eval("function(ns, MOCK) " + code + " end")(self.ns, self.m)

    def fire(self, event, *args):
        self.m.fire(event, *args)

    def slash(self, msg):
        self.lua.globals().SlashCmdList.MERCADER(msg)

    def open(self, merchant):
        self.run(f"MOCK.openMerchant({merchant})")

    def chat(self):
        return lua_list(self.m.chat)

    def keys(self, **opts):
        args = ", ".join(f"{k} = {v}" for k, v in opts.items())
        return lua_list(self.run(f"local out = {{}} for _, e in ipairs(ns.Vendors.List({{ {args} }})) do out[#out + 1] = e.key end return out"))

    def entry(self, key):
        return self.run(f"return ns.Vendors.Find({key!r})")


@pytest.fixture
def game():
    return Client().login()


# --- packaging -------------------------------------------------------------------------------------------


def test_bindings_xml_is_not_listed_in_the_toc():
    assert (ADDON / "Bindings.xml").exists()
    assert not any(ln.lower().endswith(".xml") for ln in toc_lines() if not ln.startswith("#"))


def test_toc_is_for_forever_and_has_its_art():
    lines = toc_lines()
    assert "## Interface: 16001" in lines
    assert "## SavedVariables: MercaderDB" in lines
    for name in ("icon", "pin", "pin_rumour", "dot", "glow", "emblem"):
        assert (ADDON / "Media" / f"{name}.tga").exists()
    assert toc_files()[0] == "Libs/Pergamino/Pergamino.lua"


def test_no_emoji_in_the_addon_strings():
    emoji = re.compile("[\U0001f000-\U0001faff☀-➿⬀-⯿️]")
    for path in ADDON.glob("*.lua"):
        assert not emoji.search(path.read_text(encoding="utf-8")), path.name


def test_the_addon_never_asks_for_donations():
    for path in ADDON.glob("*.lua"):
        text = path.read_text(encoding="utf-8").lower()
        assert "patreon" not in text and "donat" not in text, path.name


def test_spanish_has_no_key_english_lacks():
    c = Client()
    src = (ADDON / "Locales.lua").read_text(encoding="utf-8")
    english = set(re.findall(r"^\t([A-Z_]+) = ", src.split("local es = {")[0], re.M))
    spanish = set(re.findall(r"^\t([A-Z_]+) = ", src.split("local es = {")[1], re.M))
    assert spanish <= english
    assert c.ns.L.TITLE == "Mercader"


# --- the addon's own list --------------------------------------------------------------------------------


def test_the_list_of_rumours_is_well_formed(game):
    seed = lua_list(game.ns.Seed)
    assert len(seed) >= 50
    keys = [s.key for s in seed]
    assert len(set(keys)) == len(keys)
    for s in seed:
        items = lua_list(s["items"])
        assert items and len(set(items)) == len(items), s.name
        assert 1411 <= s.map <= 1458, s.name
        assert s.side in (None, "A", "H"), s.name
        assert (s.x is None) == (s.y is None), s.name
        if s.x is not None:
            assert 0 < s.x < 1 and 0 < s.y < 1, s.name
        else:
            assert s.place, s.name  # without a position, at least the place the wiki names


# The item ids looked up one by one on foreverdb.net on 18 Nov 2026 (name and who sells it). An id that is not
# here was never checked: it does not go in the list.
CHECKED_ITEMS = {
    858, 929, 2455, 4765, 4766, 4777, 4778, 4781, 4782, 4786, 4788, 4789, 4790, 4792, 4793, 4794, 4795, 4796,
    4797, 4798, 4799, 4800, 4816, 4817, 4818, 4820, 4821, 4822, 4824, 4825, 4826, 4827, 4828, 4829, 4830, 4831,
    4832, 4833, 4835, 4836, 4837, 4838, 5640, 5772, 6053, 7561, 11307, 11308, 12247, 12248, 12249, 12250, 12251,
    12252, 12253, 12254, 12255, 12256, 14634,
}  # fmt: skip


def test_every_item_of_the_list_was_looked_up(game):
    listed = set()
    for s in lua_list(game.ns.Seed):
        listed.update(lua_list(s["items"]))
    assert listed == CHECKED_ITEMS
    assert len(lua_list(game.ns.Seed)) == 64
    assert sum(1 for s in lua_list(game.ns.Seed) if s.x is not None) == 61
    assert sum(1 for s in lua_list(game.ns.Seed) if s.road) == 3
    assert sum(1 for s in lua_list(game.ns.Seed) if s.classic) == 10


def test_a_rumour_is_listed_until_the_player_visits(game):
    keys = game.keys()
    assert "Lizzarik@1413" in keys
    e = game.entry("Lizzarik@1413")
    assert not e.learned and e.approx and e.road == "The Crossroads - Ratchet"
    assert all(it.rumour for it in lua_list(e["items"]))
    assert game.run("return ns.Vendors.Where(ns.Vendors.Find('Lizzarik@1413'))") == "walks the road The Crossroads - Ratchet"
    assert game.run("return ns.Vendors.Where(ns.Vendors.Find('Grazlix@1413'))") == "around Ratchet (approximate)"
    game.ns.db.settings.otherSide = True
    where = "return ns.Vendors.Where(ns.Vendors.Find('%s'))"
    assert game.run(where % "Kixxle@1437") == "approximate position"  # a spot with no name of its own
    assert game.run(where % "Abigail Sawyer@1458") == "at War Quarter"  # a place, but no position


def test_rumours_of_the_other_faction_are_left_out(game):
    assert "Nargal Deatheye@1413" not in game.keys()
    game.ns.db.settings.otherSide = True
    assert "Nargal Deatheye@1413" in game.keys()
    horde = Client(side="Horde").login()
    assert "Nargal Deatheye@1413" in horde.keys()
    assert "Brak Durnad@1437" not in horde.keys()


# --- what counts -----------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "item, limited, cat",
    [
        (4817, True, "gear"),
        (4817, False, None),  # a weapon always in stock is not a find
        (2488, False, None),
        (858, True, "potion"),
        (858, False, None),  # a potion that is always there is not a find either
        (4540, False, None),  # bread
        (4540, True, "other"),
        (5640, True, "recipe"),
        (5640, False, None),
        (4496, False, None),
        (4496, True, "bag"),
        (2320, True, "other"),
        (2320, False, None),
        (999999, False, None),  # an item the client does not know
        (999999, True, "other"),
    ],
)
def test_classify(game, item, limited, cat):
    assert game.ns.Vendors.Classify(item, limited) == cat


# --- learning --------------------------------------------------------------------------------------------


def test_a_visit_writes_the_vendor_down(game):
    game.open(LIZZARIK)
    rec = game.ns.db.vendors["n3658"]
    assert rec.name == "Lizzarik" and rec.npc == 3658 and rec.map == 1413
    assert (rec.x, rec.y) == (0.57, 0.34)
    assert rec.sides.Alliance is True
    assert rec.seed == "Lizzarik@1413"
    assert sorted(rec["items"].keys()) == [858, 4777, 4778]  # the Gladius is always in stock: not a find
    assert rec["items"][4778].stock == 2 and rec["items"][4778].limited is True and rec["items"][4778].price == 26200
    assert rec["items"][858].cat == "potion" and rec["items"][4778].cat == "gear"
    # the chat line names what is in limited stock, with the game's links
    line = game.chat()[-1]
    assert "Lizzarik has limited stock" in line
    assert "|Hitem:4778" in line and "x2" in line and "|Hitem:858" in line and "x3" in line
    assert "item:2488" not in line


def test_the_visit_replaces_the_rumour_and_keeps_what_was_not_seen(game):
    game.open(LIZZARIK)
    keys = game.keys()
    assert "n3658" in keys and "Lizzarik@1413" not in keys
    e = game.entry("n3658")
    assert e.learned and e.seed == "Lizzarik@1413"
    by_id = {it.id: it for it in lua_list(e["items"])}
    assert by_id[4778].stock == 2 and not by_id[4778].rumour
    # the rumour said he also sells these; the player has not seen them yet
    assert by_id[4765].rumour and by_id[4766].rumour and by_id[2455].rumour
    assert game.run("return ns.Vendors.Where(ns.Vendors.Find('n3658'))") == "57.0, 34.0"


def test_a_vendor_of_bread_is_not_written_down(game):
    game.open("{ name = 'Innkeeper Boorand', npc = 3934, items = { {4540, -1, 25}, {2488, -1, 500} } }")
    assert game.run("return next(ns.db.vendors)") is None
    assert not any("Boorand" in line for line in game.chat())


def test_sold_out_and_gone(game):
    game.open("{ name = 'Jazzik', npc = 3498, items = { {4778, 1, 100}, {4496, -1, 500} } }")
    rec = game.ns.db.vendors["n3498"]
    assert rec["items"][4778].stock == 1
    assert rec["items"][4496] is None  # the pouch is always in stock: not written down
    game.m.now = game.m.now + 3600
    game.open("{ name = 'Jazzik', npc = 3498, items = { {2488, -1, 500} } }")
    assert rec["items"][4778].stock == 0  # limited and not in the window: sold out, still written down
    assert game.run("return ns.Vendors.StockText({ stock = 0 })") == "sold out"
    assert game.run("return ns.Vendors.StockText({ stock = 2 })") == "2 left"
    assert game.run("return ns.Vendors.StockText({ stock = -1 })") == "always in stock"
    assert game.run("return ns.Vendors.StockText({ rumour = true })") == "not confirmed"


def test_a_purchase_reads_the_window_again(game):
    game.open(LIZZARIK)
    said = len(game.chat())
    game.run("MOCK.merchant.items[1][2] = 1")
    game.fire("MERCHANT_UPDATE")
    game.fire("MERCHANT_UPDATE")
    assert len(lua_list(game.m.timers)) == 1  # several updates, one reading
    game.m.runTimers()
    assert game.ns.db.vendors["n3658"]["items"][4778].stock == 1
    assert len(game.chat()) == said  # no second chat line for the same visit


def test_without_an_npc_id_the_name_and_zone_are_the_key(game):
    game.open("{ name = 'Jazzik', items = { {4778, 1, 100} } }")
    assert game.ns.db.vendors["Jazzik@1413"].npc is None


def test_a_hidden_name_is_not_written_down(game):
    game.run("MOCK.secret['Lizzarik'] = true")
    game.open(LIZZARIK)
    assert game.run("return next(ns.db.vendors)") is None


def test_a_rumour_is_found_by_its_goods_when_the_name_is_in_another_language():
    game = Client(locale="esES", where=(1436, 0.44, 0.67)).login()
    game.open("{ name = 'Especulador Defias', npc = 1669, items = { {4788, 1, 2000} } }")
    assert game.ns.db.vendors["n1669"].seed == "Defias Profiteer@1436"
    assert "Defias Profiteer@1436" not in game.keys()


def test_two_rumours_with_the_same_goods_are_not_guessed(game):
    # three rumours of the Barrens sell the Enamelled Broadsword (4765): which one this is cannot be told
    game.open("{ name = 'Alguien', npc = 77, items = { {4765, 1, 100} } }")
    assert game.ns.db.vendors["n77"].seed is None


def test_the_announcement_can_be_turned_off(game):
    game.ns.db.settings.announce = False
    game.open(LIZZARIK)
    assert not any("limited stock" in line for line in game.chat())
    assert any("Lizzarik is written down (The Barrens)" in line for line in game.chat())


# --- the list --------------------------------------------------------------------------------------------


def test_kinds_and_search(game):
    game.open(LIZZARIK)
    assert "n3658" in game.keys(map=1413)
    cats = game.ns.db.settings.cats
    cats.gear, cats.potion = False, False
    assert "n3658" not in game.keys(map=1413)  # nothing of his is of a chosen kind
    cats.potion = True
    shown = lua_list(game.run("return ns.Vendors.ShownItems(ns.Vendors.Find('n3658'), ns.db.settings.cats)"))
    assert sorted(it.id for it in shown) == [858, 2455]
    cats.gear = True
    # by item name: every vendor an Alliance character can buy a Blessed Claymore from
    assert set(game.keys(text="'claymore'")) == {
        "Antonio Perelli@1429",
        "Brak Durnad@1437",
        "Piter Verance@1445",
        "Veenix@1442",
        "Wallace the Blind@1421",
    }
    assert game.keys(text="'  LIZZ '") == ["n3658"]
    assert game.keys(text="'nothing like this'") == []


def test_the_players_zone_comes_first(game):
    keys = game.keys()
    barrens = [k for k in keys if k.endswith("@1413")]
    assert keys[: len(barrens)] == barrens


def test_rumours_can_be_left_out(game):
    game.ns.db.settings.rumours = False
    assert game.keys() == []
    game.open(LIZZARIK)
    assert game.keys() == ["n3658"]


def test_forget_and_hide(game):
    game.open(LIZZARIK)
    assert game.ns.Vendors.Forget("n3658") == "forgotten"
    assert "Lizzarik@1413" in game.keys()  # the rumour is back
    assert game.ns.Vendors.Forget("Lizzarik@1413") == "hidden"
    assert "Lizzarik@1413" not in game.keys()
    game.slash("rumores")
    assert "Lizzarik@1413" in game.keys()
    assert "1 hidden rumours are back" in game.chat()[-1]


# --- the map ---------------------------------------------------------------------------------------------


def marks(game, shown):
    layout = game.ns.Map.Layout(shown)
    out = []
    for mark in lua_list(layout.marks):
        out.append((round(mark.x, 3), round(mark.y, 3), sorted(e.key for e in lua_list(mark.entries)), mark.rumour))
    return out, sorted(e.key for e in lua_list(layout.notes))


def test_marks_of_a_zone(game):
    got, notes = marks(game, 1413)
    # the rumours that stand together share one mark; the one that walks a road has its own
    assert got == [
        (0.62, 0.37, ["Grazlix@1413", "Vexspindle@1413"], True),
        (0.42, 0.38, ["Kiknikle@1413", "Pizznukle@1413"], True),
        (0.57, 0.34, ["Lizzarik@1413"], True),
    ]
    assert notes == []
    game.open(LIZZARIK)
    got, notes = marks(game, 1413)
    assert (0.57, 0.34, ["n3658"], False) in got and len(got) == 3


def test_a_rumour_without_a_position_goes_to_the_note(game):
    got, notes = marks(game, 1437)
    assert notes == ["Dark Iron Entrepreneur@1437"]
    assert (0.1, 0.58, ["Brak Durnad@1437", "Jennabink Powerseam@1437"], True) in got


def test_marks_on_the_continent(game):
    game.open(LIZZARIK)
    got, notes = marks(game, 1414)
    # the Barrens are drawn at 0.4-0.6 x 0.3-0.6 of Kalimdor: Ratchet (0.62, 0.37) falls on 0.524, 0.411, and
    # Lizzarik, a few steps away at that size, shares its mark, which is no longer only a rumour
    assert got == [
        (0.524, 0.411, ["Grazlix@1413", "Vexspindle@1413", "n3658"], False),
        (0.484, 0.414, ["Kiknikle@1413", "Pizznukle@1413"], True),
    ]
    assert notes == []  # the note is for the zone's own map
    assert marks(game, 1415) == ([], [])  # no rectangle known for those zones: nothing is guessed


def test_no_marks_when_turned_off(game):
    game.slash("mapa off")
    assert marks(game, 1413) == ([], [])
    assert "hidden from the world map" in game.chat()[-1]
    game.slash("mapa on")
    assert marks(game, 1413)[0]


def test_the_marks_are_drawn_on_the_canvas(game):
    game.open(LIZZARIK)
    game.run("WorldMapFrame:Show()")

    def shown():
        return [p for p in lua_list(game.ns.Map.pins) if p["_shown"]]

    assert sorted(p.count["_text"] for p in shown()) == ["", "2", "2"]
    one = next(p for p in shown() if p.count["_text"] == "")
    two = next(p for p in shown() if p.count["_text"] == "2")
    # canvas 1000 x 600 zoomed to 0.5: the mark undoes the zoom (scale 2) and its offset is in its own scale
    calls = [c for c in lua_list(one["_calls"]) if c[1] == "SetScale"]
    assert calls and calls[-1][2] == 2
    anchor = one["_points"][1]
    assert anchor[1] == "CENTER" and anchor[3] == "TOPLEFT"
    assert (anchor[4], anchor[5]) == pytest.approx((0.57 * 1000 / 2, -0.34 * 600 / 2))
    assert two.art.texture.endswith("pin_rumour") and one.art.texture.endswith("pin")
    assert game.ns.Map.note is None  # every rumour of the Barrens has a position
    # the Wetlands: one rumour has no position, and the note at the corner counts it
    game.m.shownMap = 1437
    game.run("WorldMapFrame:OnMapChanged()")
    assert len(shown()) == 3 and game.ns.Map.note["_shown"] and game.ns.Map.note.count["_text"] == "1"
    # a zone with nothing: the marks and the note go away
    game.m.shownMap = 1411
    game.run("WorldMapFrame:OnMapChanged()")
    assert shown() == [] and not game.ns.Map.note["_shown"]


def test_the_marks_sit_above_the_games_explored_areas(game):
    # the game's explored-areas overlay covers the whole map at frame level 2001: a mark below it is not seen
    def level(frame):
        return [c[2] for c in lua_list(frame["_calls"]) if c[1] == "SetFrameLevel"][-1]

    game.run("WorldMapFrame:Show()")
    assert game.m.levelAsked == "PIN_FRAME_LEVEL_AREA_POI"
    assert [level(pin) for pin in lua_list(game.ns.Map.pins)] == [2023, 2023, 2023]
    game.m.shownMap = 1437
    game.run("WorldMapFrame:OnMapChanged()")
    assert level(game.ns.Map.note) == 2028
    # a client whose map does not say: still above 2000
    game.run("WorldMapFrame.GetPinFrameLevelsManager = nil ns.Map.Draw()")
    assert level(game.ns.Map.pins[1]) == 2100


def test_the_map_report(game):
    game.slash("marcas")
    lines = game.chat()[-3:]
    assert "Map hooked: yes. Marks turned on: yes." in lines[0]
    assert "The Barrens (1413): 3 marks for 5 vendors, 0 rumours without a position." in lines[1]
    assert "The map is closed" in lines[2]
    game.run("WorldMapFrame:Show()")
    game.slash("marks")
    assert "Map open: 3 marks drawn, canvas 1000 x 600, zoom 0.50, level 2023." in game.chat()[-1]
    game.goto(None)
    game.run("WorldMapFrame:Hide()")
    game.slash("marcas")
    assert "names no zone here" in game.chat()[-1]


def test_the_map_is_hooked_later_when_the_game_makes_it_late():
    game = Client()
    game.run("MOCK.keptMap = WorldMapFrame; WorldMapFrame = nil")
    game.login()
    assert not game.ns.Map.hooked and len(lua_list(game.m.timers)) == 1
    game.run("WorldMapFrame = MOCK.keptMap")
    game.m.runTimers()
    assert game.ns.Map.hooked is True
    game.run("WorldMapFrame:Show()")
    assert any(p["_shown"] for p in lua_list(game.ns.Map.pins))


def test_open_map_points_at_the_vendor(game):
    game.ns.UI.Open("Grazlix@1413")
    game.run("ns.UI.ShowOnMap(ns.Vendors.Find('Grazlix@1413'))")
    glow = game.ns.Map.glow
    # the ring is on Ratchet's mark (the one that holds Grazlix), takes its scale and pulses
    assert glow["_shown"] and glow.on.mark.x == 0.62 and glow.on.count["_text"] == "2"
    assert game.run("local c = ns.Map.glow._calls for i = #c, 1, -1 do if c[i][1] == 'SetParent' then return c[i][2] == ns.Map.glow.on end end")
    assert glow.art.texture.endswith("glow") and game.m.played == 1
    # a few seconds later it goes away on its own
    game.m.runTimers()
    assert not glow["_shown"] and game.ns.Map.highlight is None
    # a vendor without a position: the ring goes to the note at the corner
    game.ns.UI.Open("Dark Iron Entrepreneur@1437")
    game.run("ns.UI.ShowOnMap(ns.Vendors.Find('Dark Iron Entrepreneur@1437'))")
    assert glow["_shown"] and game.run("return ns.Map.glow.on == ns.Map.note")
    # pointing at another one moves it; the first one's timer does not take it away
    game.run("ns.Map.Highlight('Brak Durnad@1437')")
    assert glow["_shown"] and game.run("return ns.Map.glow.on ~= ns.Map.note") and glow.on.mark.x == 0.1


# --- the minimap -----------------------------------------------------------------------------------------


def test_minimap_maths(game):
    off = game.ns.Mini.Offset
    # a zone of 10000 x 6000 yards, a minimap that shows 200 yards to each side and is 70 px to the rim
    x, y, dist = off(0.50, 0.50, 0.51, 0.50, 10000, 6000, 200, 70, None)
    assert (x, y, dist) == pytest.approx((35, 0, 100))  # 100 yards east: half way to the right
    x, y, dist = off(0.50, 0.50, 0.50, 0.49, 10000, 6000, 200, 70, None)
    assert (x, y, dist) == pytest.approx((0, 21, 60))  # 60 yards north: up
    x, y, dist = off(0.50, 0.50, 0.53, 0.50, 10000, 6000, 200, 70, None)
    assert x is None and dist == pytest.approx(300)  # outside
    x, y, dist = off(0.50, 0.50, 0.5185, 0.50, 10000, 6000, 200, 70, None)
    assert x is None  # 185 yards: inside the square but on the rim of a round minimap
    # the minimap turns with the player, who looks west: what is to the west is up
    import math

    x, y, dist = off(0.50, 0.50, 0.49, 0.50, 10000, 6000, 200, 70, math.pi / 2)
    assert (x, y) == pytest.approx((0, 35), abs=1e-6)


def test_minimap_sizes(game):
    # the game says how many yards the minimap shows (right in cities and buildings too)
    game.m.viewRadius = 150
    assert game.ns.Mini.Radius() == 150
    # a client that does not: the table by zoom
    game.m.viewRadius = None
    assert game.ns.Mini.Radius() == pytest.approx(233.333, abs=0.01)
    game.m.zoom = 5
    assert game.ns.Mini.Radius() == pytest.approx(66.667, abs=0.01)
    game.m.indoors = True
    assert game.ns.Mini.Radius() == 25
    assert game.ns.Mini.ZoneSize(1413) == (10000, 6000)
    assert game.ns.Mini.ZoneSize(1437) is None  # the game does not say: no marks there


def mini(game):
    out = []
    for mark in lua_list(game.ns.Mini.Layout()):
        out.append((round(mark.x, 1), round(mark.y, 1), sorted(e.key for e in lua_list(mark.entries)), mark.rumour))
    return out


def test_marks_on_the_minimap(game):
    # the player stands 100 yards west and 60 north of Ratchet (0.62, 0.37): its two rumours share one mark
    game.goto(1413, 0.61, 0.36)
    assert mini(game) == [(30.0, -18.0, ["Grazlix@1413", "Vexspindle@1413"], True)]
    assert game.ns.Mini.Update() == 1
    pin = game.ns.Mini.pins[1]
    anchor = pin["_points"][1]
    assert pin["_shown"] and (anchor[1], anchor[3]) == ("CENTER", "CENTER")
    assert (anchor[4], anchor[5]) == pytest.approx((30, -18)) and pin.art.texture.endswith("pin_rumour")
    # a visit turns it into a vendor's mark, where the player stands
    game.open("{ name = 'Grazlix', npc = 3482, items = { {4778, 1, 100} } }")
    assert (0.0, 0.0, ["n3482"], False) in mini(game)
    # far from everything, in a dungeon, or turned off: nothing
    game.goto(1413, 0.20, 0.80)
    assert mini(game) == [] and game.ns.Mini.Update() == 0 and not pin["_shown"]
    game.goto(None)
    assert mini(game) == []
    game.goto(1413, 0.61, 0.36)
    game.ns.db.settings.minimapPins = False
    assert mini(game) == []


def test_the_minimap_that_turns_with_the_player(game):
    import math

    game.goto(1413, 0.61, 0.37)  # Ratchet is 100 yards to the east
    assert mini(game)[0][:2] == (30.0, 0.0)
    game.m.cvars.rotateMinimap = "1"
    game.m.facing = -math.pi / 2  # looking east: Ratchet is straight ahead, up
    assert mini(game)[0][:2] == (0.0, 30.0)
    game.m.facing = None  # the game does not say where the player looks: nothing is drawn
    assert mini(game) == []


def test_minimap_mark_tooltip_and_click(game):
    game.goto(1413, 0.61, 0.36)
    game.ns.Mini.Update()
    pin = game.ns.Mini.pins[1]
    assert round(pin.mark.dist) == 117
    pin["_scripts"].OnClick(pin, "LeftButton")
    assert game.ns.UI.frame["_shown"] and game.ns.UI.selected == "Grazlix@1413"
    pin["_scripts"].OnClick(pin, "RightButton")
    assert game.m.waypoints[1].map == 1413


def test_tooltip_lines(game):
    game.open(LIZZARIK)
    lines = [ln[1] for ln in lua_list(game.run("return ns.Map.TipLines({ ns.Vendors.Find('n3658'), ns.Vendors.Find('Grazlix@1413') })"))]
    assert lines[0] == "Lizzarik" and lines[1] == "57.0, 34.0"
    assert any("|Hitem:4778" in ln and "2 left" in ln for ln in lines)
    assert any("not confirmed" in ln for ln in lines)
    assert "Grazlix (rumour)" in lines
    assert any(ln.strip() == "...and 2 more" for ln in lines)  # Grazlix has 8, six are shown


# --- the book --------------------------------------------------------------------------------------------


def rows(game):
    return lua_list(game.ns.UI.Rows())


def test_the_book_opens_on_this_zone(game):
    game.slash("")
    assert game.ns.UI.frame["_shown"] and game.ns.UI.scope == "zone"
    names = [r.name for r in rows(game)]
    assert names == ["Grazlix", "Kiknikle", "Lizzarik", "Pizznukle", "Vexspindle"]
    assert all(r.rumour and r.zone == "The Barrens" for r in rows(game))
    game.slash("")
    assert not game.ns.UI.frame["_shown"]


def test_the_book_opens_on_everything_when_the_zone_has_nothing():
    game = Client(where=(1453, 0.5, 0.5)).login()
    game.ns.db.settings.rumours = False
    game.slash("")
    assert game.ns.UI.scope == "all"


def test_the_chosen_vendor(game):
    game.open(LIZZARIK)
    game.ns.UI.Open("n3658")
    d = game.ns.UI.Detail()
    assert d.title == "Lizzarik" and d.where == "The Barrens · 57.0, 34.0"
    assert d.status == "You saw this stock a moment ago." and d.canMark and d.forget == "Forget"
    items = lua_list(d["items"])
    assert items[0].id == 4777 and "2 left" in items[0].stock and "item:4777" in items[0].link
    assert any(it.rumour and it.stock == "not confirmed" for it in items)
    game.ns.UI.Open("Grazlix@1413")
    d = game.ns.UI.Detail()
    assert d.where == "The Barrens · around Ratchet (approximate)" and d.forget == "Hide" and d.canMark
    assert "other players saw this stock in Forever" in d.status
    game.ns.UI.Open("Dark Iron Entrepreneur@1437")
    d = game.ns.UI.Detail()
    assert not d.canMark and d.where == "Zone 1437 · at Thandol Span"


def test_the_book_goes_over_the_open_map(game):
    def strata():
        calls = [c for c in lua_list(game.ns.UI.frame["_calls"]) if c[1] == "SetFrameStrata"]
        return calls[-1][2]

    game.slash("")
    assert strata() == "HIGH"
    game.run("WorldMapFrame:Show()")
    game.ns.UI.Open("Grazlix@1413")  # a click on a mark, with the book already open
    assert strata() == "FULLSCREEN_DIALOG"


def test_a_rumour_nobody_confirmed_says_so(game):
    game.ns.UI.Open("Charys Yserian@1453")
    assert "nobody confirmed it in Forever" in game.ns.UI.Detail().status
    # she is not in the player's zone: the list turns to hers
    assert game.ns.UI.scope == "pick" and game.ns.UI.zone == 1453
    assert [r.name for r in rows(game)] == ["Charys Yserian", "Frederick Stover"]


def test_pick_a_zone_from_the_menu(game):
    game.slash("")
    f = game.ns.UI.frame
    f.scopePick["_scripts"].OnClick(f.scopePick)
    items = lua_list(game.m.lastMenu["items"])
    titles = [i.text for i in items if i.kind == "title"]
    assert titles == ["Eastern Kingdoms", "Kalimdor"]  # zones the stand-in knows no continent for come first
    radios = [i.text for i in items if i.kind == "radio"]
    assert "The Barrens (5)" in radios and "Stormwind City (2)" in radios and "Westfall (1)" in radios
    assert radios.index("Elwynn Forest (1)") < radios.index("Hillsbrad Foothills (3)") < radios.index("The Barrens (5)")
    game.m.clickMenu("Hillsbrad Foothills (3)")
    assert game.ns.UI.scope == "pick" and game.ns.UI.zone == 1424
    assert [r.name for r in rows(game)] == ["Kris Legace", "Robert Aebischer", "Zixil"]
    assert f.scopePick["_text"] == "Hillsbrad Foothills" and f.scopePick.pressed and not f.scopeZone.pressed
    # the picked zone stays when the book is closed and opened again; "this zone" goes back to the player's
    game.slash("")
    game.slash("")
    assert game.ns.UI.scope == "pick"
    f.scopeZone["_scripts"].OnClick(f.scopeZone)
    assert [r.zone for r in rows(game)] == ["The Barrens"] * 5 and f.scopePick["_text"] == "Zone..."


def test_search_by_zone_name(game):
    game.slash("buscar hillsbrad")
    assert [r.name for r in rows(game)] == ["Kris Legace", "Robert Aebischer", "Zixil"]
    assert game.ns.UI.frame.scopeAll.pressed


def test_this_zone_inside_a_dungeon_is_everywhere():
    game = Client(where=(None, None, None)).login()
    game.slash("")
    f = game.ns.UI.frame
    assert len(rows(game)) > 30 and f.scopeAll.pressed and not f.scopeZone.pressed
    f.scopeZone["_scripts"].OnClick(f.scopeZone)
    assert len(rows(game)) > 30 and f.scopeAll.pressed  # the client names no zone: nothing to narrow to


def test_bring_hidden_rumours_back_with_a_click(game):
    game.slash("")
    f = game.ns.UI.frame
    assert not f.hiddenChip["_shown"] and f.unhide["_text"] == "Show the hidden rumours (0)"
    game.ns.UI.Open("Grazlix@1413")
    game.ns.UI.Forget()
    game.ns.UI.Open("Vexspindle@1413")
    game.ns.UI.Forget()
    assert "The button under the list" in game.chat()[-1]
    assert f.hiddenChip["_shown"] and f.hiddenChip["_text"] == "Show hidden (2)"
    assert f.unhide["_text"] == "Show the hidden rumours (2)"
    assert "Grazlix" not in [r.name for r in rows(game)]
    f.hiddenChip["_scripts"].OnClick(f.hiddenChip)
    assert "2 hidden rumours are back" in game.chat()[-1]
    assert not f.hiddenChip["_shown"] and "Grazlix" in [r.name for r in rows(game)]
    game.ns.UI.Open("Grazlix@1413")
    game.ns.UI.Forget()
    f.unhide["_scripts"].OnClick(f.unhide)
    assert game.ns.Vendors.HiddenCount() == 0


def test_a_found_vendor_with_nothing_in_stock(game):
    game.open("{ name = 'Lizzarik', npc = 3658, items = { {2488, -1, 500} } }")
    game.ns.UI.Open("n3658")
    assert game.ns.UI.Detail().status == "You found this vendor, but nothing of the list was in stock."


def test_search_from_chat(game):
    game.slash("buscar Agile Boots")
    assert game.ns.UI.frame["_shown"] and game.ns.UI.text == "Agile Boots"
    names = {r.name for r in rows(game)}
    assert names == {"Pizznukle", "Kat Sampson", "Defias Profiteer"}  # the Horde one is left out


def test_mark_on_the_map(game):
    game.open(LIZZARIK)
    assert game.run("return ns.UI.Waypoint(ns.Vendors.Find('n3658'))") is True
    wp = game.m.waypoints[1]
    assert (wp.map, wp.x, wp.y) == (1413, 0.57, 0.34) and game.m.superTracked is True
    assert "Lizzarik is marked on your map" in game.chat()[-1]
    game.m.canWaypoint = False
    assert game.run("return ns.UI.Waypoint(ns.Vendors.Find('n3658'))") is False
    assert "cannot put a mark there" in game.chat()[-1]
    assert game.run("return ns.UI.Waypoint(ns.Vendors.Find('Kiknikle@1413'))") is False  # no position


def test_open_the_map_on_the_vendors_zone(game):
    game.ns.UI.Open("Veenix@1442")
    game.run("ns.UI.ShowOnMap(ns.Vendors.Find('Veenix@1442'))")
    assert lua_list(game.m.openedMaps) == [1442]
    assert not game.ns.UI.frame["_shown"]


def test_item_names_that_arrive_late(game):
    # a rumour's item the client has not loaded: "Item 4765" for now, asked for, and looked at again in a moment
    game.run("MOCK.itemData[4765].cached = false")
    game.open(LIZZARIK)
    game.ns.UI.Open("n3658")
    items = {it.id: it for it in lua_list(game.ns.UI.Detail()["items"])}
    assert "[Item 4765]" in items[4765].link and items[4765].unnamed and not items[4778].unnamed
    assert 4765 in lua_list(game.m.requested)
    assert len(lua_list(game.m.timers)) == 1  # the page waits for the name
    game.m.cacheItem(4765)
    game.m.runTimers()
    items = {it.id: it for it in lua_list(game.ns.UI.Detail()["items"])}
    assert "[Enamelled Broadsword]" in items[4765].link and not items[4765].unnamed
    assert len(lua_list(game.m.timers)) == 0  # every name is there: no more waiting
    # the game's own news that items arrived redraw the page once for the whole batch
    fired = []
    game.ns.On("items", lambda: fired.append(1))
    game.fire("GET_ITEM_INFO_RECEIVED", 4778, True)
    game.fire("ITEM_DATA_LOAD_RESULT", 4777, True)
    game.m.runTimers()
    assert fired == [1]


def test_the_name_read_at_the_window_is_kept(game):
    # the client has not loaded the item, but the vendor's window named it: that name is used, today and later
    game.run("MOCK.itemData[4778].cached = false")
    game.open(LIZZARIK)
    game.ns.UI.Open("n3658")
    items = {it.id: it for it in lua_list(game.ns.UI.Detail()["items"])}
    assert "[Heavy Spiked Mace]" in items[4778].link and not items[4778].unnamed
    assert game.ns.db.names[4778] == "Heavy Spiked Mace"
    assert game.keys(text="'spiked'")[0] == "n3658"  # and the search finds it


def test_a_name_that_never_comes_stops_being_asked_for(game):
    game.run("MOCK.itemData[4765].cached = false")
    game.open(LIZZARIK)
    game.ns.UI.Open("n3658")
    for _ in range(12):
        game.m.runTimers()
    assert game.ns.UI.nameTries == 5 and len(lua_list(game.m.timers)) == 0


def test_nothing_picked_shows_the_books_own_page(game):
    game.open(LIZZARIK)
    game.slash("")
    f = game.ns.UI.frame
    w = f.welcome
    assert w["_shown"] and not f.itemsHolder["_shown"] and f.name["_text"] == ""
    assert w.title["_text"] == "Vendors worth the trip" and w.emblem.texture.endswith("emblem")
    assert w.legend[1].art.texture.endswith("pin") and w.legend[2].art.texture.endswith("pin_rumour")
    assert "Rumour" in w.legend[2].label["_text"]
    # what an Alliance character can see: 64 less the 17 of the Horde, and Lizzarik visited
    assert w.stats["_text"] == "Known: 47 · Visited: 1"
    game.ns.UI.Open("n3658")
    assert not w["_shown"] and f.itemsHolder["_shown"] and f.name["_text"] == "Lizzarik"
    # the list turns to a zone where he is not: nothing of the list is picked, so the right page says so
    game.ns.UI.PickZone(1424)
    assert w["_shown"] and not f.mark["_shown"] and f.name["_text"] == ""
    game.ns.UI.PickZone(1413)
    assert not w["_shown"] and f.name["_text"] == "Lizzarik"  # back on the list, back on the page


def test_every_kind_turned_off(game):
    game.slash("")
    f = game.ns.UI.frame
    for cat in ("gear", "potion", "recipe", "bag", "other"):
        game.ns.db.settings.cats[cat] = False
    game.ns.UI.Refresh()
    assert rows(game) == [] and "Every kind of goods is turned off" in f.empty["_text"]
    # the zone menu still lists the zones, and one can be picked
    f.scopePick["_scripts"].OnClick(f.scopePick)
    radios = [i.text for i in lua_list(game.m.lastMenu["items"]) if i.kind == "radio"]
    assert "The Barrens (5)" in radios
    game.m.clickMenu("Hillsbrad Foothills (3)")
    assert game.ns.UI.zone == 1424 and f.scopePick["_text"] == "Hillsbrad Foothills"


def test_zone_to_chat(game):
    game.open(LIZZARIK)
    said = len(game.chat())
    assert game.ns.UI.ZoneToChat() == 5
    lines = game.chat()[said:]
    assert any("Lizzarik, 57.0, 34.0" in ln and "|Hitem:4777" in ln for ln in lines)
    assert any("Grazlix (rumour), around Ratchet (approximate)" in ln and "..." in ln for ln in lines)


# --- settings, language, slash ----------------------------------------------------------------------------


def test_saved_variables_are_made_and_mended():
    game = Client(saved="MercaderDB = { settings = { lang = 'xx', pins = 'yes', cats = { gear = false } }, vendors = 3 }").login()
    s = game.ns.db.settings
    assert s.lang == "auto" and s.pins is True and s.rumours is True and s.announce is True and s.otherSide is False
    assert s.cats.gear is False and s.cats.potion is True and s.cats.other is True
    assert s.minimapPins is True
    assert game.run("return type(ns.db.vendors)") == "table"
    assert "MercaderDB" in game.m.savedVariables("MercaderDB")


def test_what_the_first_builds_kept_without_a_limit_goes():
    saved = """MercaderDB = { vendors = {
        n1 = { name = "General", map = 1413, x = 0.5, y = 0.5, t = 1, sides = {}, items = {
            [4496] = { cat = "bag", stock = -1, limited = false, price = 500, t = 1 } } },
        n2 = { name = "Jazzik", map = 1413, x = 0.6, y = 0.4, t = 1, sides = {}, items = {
            [4496] = { cat = "bag", stock = -1, limited = false, price = 500, t = 1 },
            [4778] = { cat = "gear", stock = 2, limited = true, price = 100, t = 1 } } },
        n3658 = { name = "Lizzarik", map = 1413, x = 0.57, y = 0.34, t = 1, sides = {}, seed = "Lizzarik@1413", items = {
            [858] = { cat = "potion", stock = -1, limited = false, price = 100, t = 1 } } },
        broken = 7,
    } }"""
    game = Client(saved=saved).login()
    v = game.ns.db.vendors
    assert v["n1"] is None and v["broken"] is None  # nothing limited left: the vendor goes
    assert v["n2"] is not None and v["n2"]["items"][4496] is None and v["n2"]["items"][4778].stock == 2
    # a vendor a rumour was about stays found, even with nothing left written down
    assert v["n3658"] is not None and v["n3658"]["items"][858] is None
    assert game.ns.db.version == 2


def test_spanish():
    game = Client(locale="esMX").login()
    game.open(LIZZARIK)
    assert "Lizzarik tiene stock limitado" in game.chat()[-1]
    game.ns.UI.Open("n3658")
    assert game.ns.UI.Detail().status == "Viste este stock hace un momento."
    game.slash("idioma en")
    assert game.ns.UI.Detail().status == "You saw this stock a moment ago."
    assert "Language: English." in game.chat()[-1]
    assert game.ns.UI.frame.cats.gear["_text"] == "Gear"
    game.slash("idioma")
    assert "/mercader idioma" in game.chat()[-1]


def test_zones_check(game):
    game.slash("zonas")
    lines = game.chat()
    assert any(ln.endswith("1413: The Barrens") for ln in lines)
    assert any("1445: not in this client" in ln for ln in lines)  # the stand-in does not know Dustwallow
    total, missing = game.ns.Zones()
    assert total > 20 and 0 < missing < total


def test_minimap_button_and_help(game):
    assert game.ns.UI.minimap is not None
    game.slash("minimapa off")
    assert game.ns.db.settings.minimap is False
    game.slash("minimapa on")
    assert game.ns.db.settings.minimap is True
    game.slash("ayuda")
    assert "/mercader buscar" in game.chat()[-1]


def test_options_page(game):
    game.slash("")
    f = game.ns.UI.frame
    f.checks.announce.checked = False
    f.checks.announce["_scripts"].OnClick(f.checks.announce)
    assert game.ns.db.settings.announce is False
    f.cats.gear["_scripts"].OnClick(f.cats.gear)
    assert game.ns.db.settings.cats.gear is False
    assert "Pizznukle" not in [r.name for r in rows(game)]  # his boots are gear


def test_compartment_and_binding(game):
    g = game.lua.globals()
    g.Mercader_OnAddonCompartmentClick()
    assert game.ns.UI.frame["_shown"]
    g.Mercader_Toggle()
    assert not game.ns.UI.frame["_shown"]
    assert g.BINDING_NAME_MERCADER_TOGGLE == "Open / close"
