# Mercader

For **WoW Forever** players who do not want to cross half the world to find out whether a vendor has *that* limited-stock green sword. Mercader puts the **vendors worth the trip** on your map: limited-stock gear, potions, limited-stock recipes, bags and other limited goods.

It works two ways at once:

- **It learns by itself.** Every time you open a vendor's window it writes down what is worth it, how many were left and where you were standing. Next time the vendor is on your map, at the exact spot.
- **It starts with its own list of rumours**: 64 vendors known for their limited stock, so the map is not empty on day one. A rumour is just that: its position is approximate (the town's) and it looks different from a vendor you visited. Once you visit, what you saw replaces the rumour.

[Leer en castellano](README.md)

## How to use it

**On the world map** (M): every mark is a little pouch: on gold it is a vendor you visited, on pale parchment it is a rumour. Vendors standing together (a town's shops) share one mark with a number. Hover to see who it is, where, and what they sell with how many were left. Click: open it in the book. Right click: mark the way with the game's own arrow. Almost every rumour has its mark (61 of 64); the three nobody placed are gathered in a small note at the bottom-left corner of their zone's map. On the continents' maps the marks are off by default, so they do not cover the map; Options turns them on.

**On the minimap**: the vendors of your zone that fall inside what the minimap shows, with the same marks. Hover for the distance in yards and the goods. It can be turned off in Options.

**The book** opens with `/mercader`, the minimap button (right click: this zone's vendors, in chat), a key binding or the addon compartment.

- Left page: search by **vendor, item or zone** ("who sells Agile Boots?", "hillsbrad"), where to look (**This zone**, **Everywhere** or **Zone...**, a menu of the zones that have something, by continent), the kinds of goods (Gear, Potions, Recipes, Bags, Other) and the list. If you hid rumours, a button under the list brings them back.
- Right page, the chosen vendor: where it is, what it sells and how many were left last time (hover an item for its tooltip; Shift-click links it in chat), and the buttons **Mark the way**, **Open map** (the map turns to the vendor's zone and a gold ring pulses around its mark for a few seconds) and **Forget** (or **Hide**, for a rumour).
- The Options tab: map and minimap marks, rumours, the other faction's vendors, the chat line, the minimap button and the language.

**In chat**, when you open a vendor with limited stock: "Mercader: Lizzarik has limited stock: [Heavy Spiked Mace] x2, [Lesser Healing Potion] x3". It can be turned off in Options.

Commands: `/mercader buscar NAME` (or `search`), `/mercader mapa on|off`, `/mercader rumores` (bring hidden rumours back), `/mercader zonas` (the list's zones as your client names them), `/mercader marcas` (what the map is drawing), `/mercader exportar` (what you saw, as text to copy), `/mercader minimapa on|off` (`juntar on|off`: one button for the whole addon family), `/mercader idioma es|en|auto`, `/mercader errores`.

## What it writes down

Only what a vendor has in **limited stock**: what is always there is not a find. The kinds are there to filter:

| Kind | What goes in (always in limited stock) |
|---|---|
| Gear | Weapons and armour |
| Potions | Potions, elixirs and flasks |
| Recipes | Recipes |
| Bags | Bags and quivers |
| Other | Anything else |

Limited stock is what the game itself reports in the vendor window. A limited item that is no longer in the window stays written down as **sold out**; a vendor of bread and water is not written down. Data is saved per account (`MercaderDB`).

## Where the list of rumours comes from

It was put together by hand, item by item, on 18 Nov 2026. It does not copy any other addon's database.

- **Who sells what**: the public item pages of [foreverdb.net](https://foreverdb.net), one look-up for each of the list's 59 items. That site tells apart what a player already saw in Forever from what is still Classic data, and Mercader says the same.
- **Where**: the town or spot each vendor's page on [warcraft.wiki.gg](https://warcraft.wiki.gg) names, one look-up per vendor, with the **town's** position to the nearest map point (in cities, the district's). That is why the game says "around Ratchet (approximate)". Of 64 rumours, 61 have an approximate position (3 of them walk a road, and their mark is on it) and 3 only a place.

Mercader takes none of this as true: it is a starting point, and what you see replaces it.

## Install

Copy the `Mercader` folder to `Interface\AddOns\` inside the game's Forever folder (`World of Warcraft\_forever_\Interface\AddOns`).

## How it was tested

- Every game function it uses exists in Forever 1.60.1 (`tools/check_api.py`); forever-lint: no errors; Addon Sentry: no risk signals; 85 tests in Lua 5.1 on a stand-in client; the 59 item ids checked one by one.
- **Seen in the client** (Forever 1.60.1, 18 Nov 2026): the book, learning a vendor with its limited stock, sold-out items and prices, the chat line, the marks on the zone and continent maps and on the minimap, and "Mark the way".
- **Not seen in the client yet:** the ring of "Open map", the book's page with no vendor chosen, and each rumour's approximate position.

If something fails, `/mercader errores` shows the addon's last error to copy into a GitHub issue.

Not affiliated with Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc. MIT licence.

## Support

All of this is free and open source, and will stay that way: no paid features, nothing early for supporters. If it helped and you want to back the time it takes to maintain it, you can do so on [Patreon](https://www.patreon.com/cw/DoblePupi). Thank you ♥
