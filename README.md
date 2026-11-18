# Mercader

Para los que juegan **WoW Forever** y no quieren recorrer medio mundo para ver si un vendedor tiene *esa* espada verde de stock limitado. Mercader marca en tu mapa los **vendedores que valen el viaje**: equipo de stock limitado, pociones, recetas de stock limitado, bolsas y otros objetos limitados.

Funciona de dos maneras a la vez:

- **Aprende solo.** Cada vez que abrís la ventana de un vendedor, anota lo que vale la pena de lo que vende, cuánto quedaba y dónde estabas parado. La próxima vez está en el mapa, con la posición exacta.
- **Arranca con una lista propia de rumores**: 64 vendedores conocidos por su stock limitado, para que el mapa no esté vacío el primer día. Un rumor es eso, un rumor: su posición es aproximada (la del pueblo) y en el juego se ve distinto a un vendedor que visitaste. Cuando lo visitás, lo que viste vos reemplaza al rumor.

[Read in English](README.en.md)

**Contenido**

- [Cómo se usa](#cómo-se-usa)
- [Qué anota](#qué-anota)
- [De dónde sale la lista de rumores](#de-dónde-sale-la-lista-de-rumores)
- [Instalar](#instalar)
- [Cómo se probó](#cómo-se-probó)
- [Desarrollo](#desarrollo)
- [Apoyar](#apoyar)

## Cómo se usa

**En el mapa del mundo** (tecla M): una moneda dorada es un vendedor que visitaste; un aro pálido es un rumor. Los vendedores que están juntos (los de un mismo pueblo) comparten una marca con un número. Pasando el mouse ves quién es, dónde está y qué vende, con cuánto quedaba. Clic: lo abre en el libro. Clic derecho: marca el camino con la flecha del juego. Los rumores de la zona que todavía no tienen posición (los que caminan por una ruta, o los que nadie ubicó) quedan en una notita en la esquina de abajo a la izquierda del mapa. En el mapa del continente se ven las marcas de sus zonas.

**El libro** se abre con `/mercader`, con el botón del minimapa (clic derecho: los vendedores de esta zona, en el chat), con el atajo de teclado o desde el compartimento de addons.

- A la izquierda: buscar por **vendedor u objeto** ("¿quién vende Agile Boots?"), los tipos de objeto (Equipo, Pociones, Recetas, Bolsas, Otros), "Esta zona / Todo" y la lista.
- A la derecha, el vendedor elegido: dónde está, qué vende y cuánto quedaba la última vez (pasando el mouse por un objeto ves su tooltip; Shift-clic lo pega en el chat), y los botones **Marcar camino**, **Ver mapa** y **Olvidar** (o **Ocultar**, si es un rumor).
- La pestaña Opciones: mostrar o no las marcas del mapa, los rumores, los vendedores de la otra facción, el aviso del chat, el botón del minimapa y el idioma.

**En el chat**, al abrir un vendedor que tiene stock limitado: "Mercader: Lizzarik tiene stock limitado: [Heavy Spiked Mace] x2, [Lesser Healing Potion] x3". Se apaga en Opciones.

Comandos:

- `/mercader buscar NOMBRE` busca un vendedor o un objeto.
- `/mercader mapa on|off` muestra u oculta las marcas del mapa.
- `/mercader rumores` trae de vuelta los rumores que ocultaste.
- `/mercader zonas` lista las zonas de la lista propia con el nombre que les da tu cliente (sirve para revisar que la lista coincide con el juego).
- `/mercader minimapa on|off` (y `juntar on|off`: un solo botón para toda la familia de addons), `/mercader idioma es|en|auto`, `/mercader errores`.

## Qué anota

| Tipo | Qué entra |
|---|---|
| Equipo | Armas y armaduras **de stock limitado** (las verdes de las que el vendedor tiene dos) |
| Pociones | Pociones, elixires y frascos, con o sin límite |
| Recetas | Recetas **de stock limitado** |
| Bolsas | Bolsas y carcajes, con o sin límite |
| Otros | Cualquier otro objeto de stock limitado |

El stock limitado es el que informa el propio juego en la ventana del vendedor. Un objeto limitado que ya no está en la ventana queda anotado como **agotado** (para que sepas que ahí se vende); un vendedor que solo vende pan y agua no se anota.

Los datos se guardan por cuenta (`MercaderDB`): lo que aprende un personaje lo ven todos. Un vendedor que visitaste con un personaje de una facción no se le muestra a los de la otra, salvo que lo pidas en Opciones.

## De dónde sale la lista de rumores

La armé a mano, objeto por objeto, el 18/11/2026. No copia la base de datos de ningún otro addon.

- **Quién vende qué**: las páginas públicas de objetos de [foreverdb.net](https://foreverdb.net), una consulta por cada uno de los 59 objetos de la lista. Esa página distingue lo que algún jugador ya vio en Forever de lo que todavía es dato de Classic, y Mercader lo dice igual: "otros jugadores vieron este stock en Forever" o "esto viene de Classic y todavía nadie lo confirmó".
- **Dónde**: el pueblo donde se sabe que está el vendedor en Classic, con la posición **del pueblo**, al punto entero. Por eso el juego dice "por Ratchet (aproximado)" y no da coordenadas finas. De 64 rumores, 31 tienen posición aproximada y 33 solo la zona (o la ruta que recorren).
- Los identificadores de zona siguen la numeración de Classic. foreverdb.net, que saca sus mapas del cliente de Forever, usa esos mismos números (comprobé Durotar 1411, Los Baldíos 1413 y Ventormenta 1453); el resto lo revisa `/mercader zonas` en tu cliente.

Mercader no da nada de esto por cierto: es un punto de partida, y lo que ves vos lo reemplaza.

## Instalar

Copiá la carpeta `Mercader` a `Interface\AddOns\`, dentro de la carpeta de Forever del juego (`World of Warcraft\_forever_\Interface\AddOns`).

## Cómo se probó

**Probado:**
- ✅ Cada función del juego que usa existe en Forever 1.60.1: `tools/check_api.py` contra los dumps de [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) y la UI de [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).
- ✅ [forever-lint](https://github.com/JoseArgento/forever-lint): sin errores. [Addon Sentry](https://github.com/JoseArgento/addon-sentry): "Sin señales de riesgo".
- ✅ **61 tests** en Lua 5.1 (el Lua de WoW) sobre un cliente simulado: qué se anota y qué no, stock que baja y se agota, rumores reemplazados por la visita, facciones, búsqueda, marcas agrupadas en la zona y en el continente, el libro, el camino marcado, castellano e inglés.
- ✅ Los 59 identificadores de objeto de la lista, uno por uno contra foreverdb.net (un test los fija).

**Todavía sin ver en el cliente ⏳** (el addon es nuevo; nada de esto se probó dentro del juego):
- Que las marcas se dibujen bien sobre el mapa de Forever: tamaño, que queden por encima del arte del mapa y que sigan el zoom.
- Que `C_MerchantFrame.GetItemInfo` informe el stock limitado como en retail (`numAvailable`, -1 sin límite) y que el id del vendedor salga de `UnitGUID("npc")`.
- Que `C_Map.SetUserWaypoint` (el camino marcado) funcione en Forever; si no, el botón avisa que no se puede.
- Las posiciones aproximadas de los rumores: son de memoria de Classic, a nivel pueblo. `/mercader zonas` muestra si los identificadores de zona coinciden con el cliente.

**Si algo falla:** `/mercader errores` muestra el último error del addon (se guardan los últimos 10, sin popups) para copiarlo en un issue de GitHub.

## Desarrollo

```bash
pip install pytest lupa
pytest
python tools/check_api.py --bir ../BlizzardInterfaceResources --ui ../wow-ui-source --scanner ../addon-sentry/src
python tools/make_icon.py   # redibuja el ícono y las marcas del mapa (arte propio)
```

`Bindings.xml` no va en el TOC: el juego lo carga solo. Un tag `v*` empaqueta el addon con el packager de BigWigs. La lista de rumores está en `Mercader/Seed.lua`, con sus fuentes arriba.

Sin relación con Blizzard Entertainment. World of Warcraft es marca registrada de Blizzard Entertainment, Inc. Licencia MIT.

## Apoyar

Todo esto es gratis y de código abierto, y va a seguir así: no hay funciones pagas ni nada antes para quien aporta. Si te sirvió y querés bancar el tiempo de mantenerlo, podés hacerlo en [Patreon](https://www.patreon.com/cw/DoblePupi). Gracias ♥
