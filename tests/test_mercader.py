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
    for name in ("icon", "pin", "pin_rumour"):
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
            assert s.place, s.name  # an approximate position always says of which town


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
    assert sum(1 for s in lua_list(game.ns.Seed) if s.x is not None) == 31
    assert sum(1 for s in lua_list(game.ns.Seed) if s.classic) == 10


def test_a_rumour_is_listed_until_the_player_visits(game):
    keys = game.keys()
    assert "Lizzarik@1413" in keys
    e = game.entry("Lizzarik@1413")
    assert not e.learned and e.x is None and e.road == "The Crossroads - Ratchet"
    assert all(it.rumour for it in lua_list(e["items"]))
    assert game.run("return ns.Vendors.Where(ns.Vendors.Find('Lizzarik@1413'))") == "walks the road The Crossroads - Ratchet"
    assert game.run("return ns.Vendors.Where(ns.Vendors.Find('Grazlix@1413'))") == "around Ratchet (approximate)"


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
        (858, False, "potion"),
        (4540, False, None),  # bread
        (4540, True, "other"),
        (5640, True, "recipe"),
        (5640, False, None),
        (4496, False, "bag"),
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
    assert rec["items"][4778].stock == 1 and rec["items"][4496].stock == -1
    game.m.now = game.m.now + 3600
    game.open("{ name = 'Jazzik', npc = 3498, items = { {2488, -1, 500} } }")
    assert rec["items"][4778].stock == 0  # limited and not in the window: sold out, still written down
    assert rec["items"][4496] is None  # it was always in stock and is not sold any more: gone
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
    # Ratchet's two rumours share one mark; the rumours without a position are the note
    assert got == [(0.62, 0.37, ["Grazlix@1413", "Vexspindle@1413"], True)]
    assert notes == ["Kiknikle@1413", "Lizzarik@1413", "Pizznukle@1413"]
    game.open(LIZZARIK)
    got, notes = marks(game, 1413)
    assert (0.57, 0.34, ["n3658"], False) in got
    assert "Lizzarik@1413" not in notes


def test_marks_on_the_continent(game):
    game.open(LIZZARIK)
    got, notes = marks(game, 1414)
    # the Barrens are drawn at 0.4-0.6 x 0.3-0.6 of Kalimdor: Ratchet (0.62, 0.37) falls on 0.524, 0.411, and
    # Lizzarik, a few steps away at that size, shares its mark, which is no longer only a rumour
    assert got == [(0.524, 0.411, ["Grazlix@1413", "Vexspindle@1413", "n3658"], False)]
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
    pins = lua_list(game.ns.Map.pins)
    shown = [p for p in pins if p["_shown"]]
    assert len(shown) == 2
    by_count = {p.count["_text"]: p for p in shown}
    two, one = by_count["2"], by_count[""]
    # canvas 1000 x 600 zoomed to 0.5: the mark undoes the zoom (scale 2) and its offset is in its own scale
    calls = [c for c in lua_list(one["_calls"]) if c[1] == "SetScale"]
    assert calls and calls[-1][2] == 2
    anchor = one["_points"][1]
    assert anchor[1] == "CENTER" and anchor[3] == "TOPLEFT"
    assert (anchor[4], anchor[5]) == pytest.approx((0.57 * 1000 / 2, -0.34 * 600 / 2))
    assert two.art.texture.endswith("pin_rumour") and one.art.texture.endswith("pin")
    assert game.ns.Map.note.count["_text"] == "2"
    # another zone: the marks of this one go away
    game.m.shownMap = 1429
    game.run("WorldMapFrame:OnMapChanged()")
    assert not any(p["_shown"] for p in lua_list(game.ns.Map.pins))


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
    game.ns.UI.Open("Kiknikle@1413")
    assert not game.ns.UI.Detail().canMark


def test_a_rumour_nobody_confirmed_says_so(game):
    game.ns.UI.Open("Charys Yserian@1453")
    assert "nobody confirmed it in Forever" in game.ns.UI.Detail().status
    assert game.ns.UI.scope == "all"  # she is not in the player's zone


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
    game.run("MOCK.itemData[4778].cached = false")
    game.open(LIZZARIK)
    game.ns.UI.Open("n3658")
    items = {it.id: it for it in lua_list(game.ns.UI.Detail()["items"])}
    assert "[Item 4778]" in items[4778].link
    assert 4778 in lua_list(game.m.requested)
    game.m.cacheItem(4778)
    fired = []
    game.ns.On("items", lambda: fired.append(1))
    game.fire("GET_ITEM_INFO_RECEIVED", 4778, True)
    game.fire("GET_ITEM_INFO_RECEIVED", 4777, True)
    game.m.runTimers()
    assert fired == [1]
    items = {it.id: it for it in lua_list(game.ns.UI.Detail()["items"])}
    assert "[Heavy Spiked Mace]" in items[4778].link


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
    assert game.run("return type(ns.db.vendors)") == "table"
    assert "MercaderDB" in game.m.savedVariables("MercaderDB")


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
