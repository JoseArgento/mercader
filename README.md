# Mercader

Para los que juegan **WoW Forever** y no quieren recorrer medio mundo para ver si un vendedor tiene *esa* espada verde de stock limitado. Mercader marca en tu mapa los **vendedores que valen el viaje**: los que tienen algo de **stock limitado**, sea equipo, pociones, recetas, bolsas u otros objetos.

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

**En el mapa del mundo** (tecla M): cada marca es una bolsita: sobre fondo dorado es un vendedor que visitaste, sobre fondo claro es un rumor. Los vendedores que están juntos (los de un mismo pueblo) comparten una marca con un número. Pasando el mouse ves quién es, dónde está y qué vende, con cuánto quedaba. Clic: lo abre en el libro. Clic derecho: marca el camino con la flecha del juego. Casi todos los rumores tienen su marca (61 de 64); los tres que nadie ubicó quedan en una notita en la esquina de abajo a la izquierda del mapa de su zona. En el mapa del continente se ven las marcas de sus zonas.

**En el minimapa**: los vendedores de tu zona que quedan dentro de lo que muestra el minimapa, con las mismas marcas. Pasando el mouse dice a cuántas yardas está y qué vende. Se apaga en Opciones.

**El libro** se abre con `/mercader`, con el botón del minimapa (clic derecho: los vendedores de esta zona, en el chat), con el atajo de teclado o desde el compartimento de addons.

- A la izquierda: buscar por **vendedor, objeto o zona** ("¿quién vende Agile Boots?", "hillsbrad"), dónde mirar (**Esta zona**, **Todo** o **Zona...**, que abre un menú con las zonas que tienen algo, por continente), los tipos de objeto (Equipo, Pociones, Recetas, Bolsas, Otros) y la lista. Si ocultaste rumores, abajo de la lista aparece un botón para traerlos de vuelta.
- A la derecha, el vendedor elegido: dónde está, qué vende y cuánto quedaba la última vez (pasando el mouse por un objeto ves su tooltip; Shift-clic lo pega en el chat), y los botones **Marcar camino**, **Ver mapa** (abre el mapa en su zona y un anillo dorado late unos segundos alrededor de su marca) y **Olvidar** (o **Ocultar**, si es un rumor).
- La pestaña Opciones: mostrar o no las marcas del mapa y las del minimapa, los rumores, los vendedores de la otra facción, el aviso del chat, el botón del minimapa y el idioma.

**En el chat**, al abrir un vendedor que tiene stock limitado: "Mercader: Lizzarik tiene stock limitado: [Heavy Spiked Mace] x2, [Lesser Healing Potion] x3". Se apaga en Opciones.

Comandos:

- `/mercader buscar NOMBRE` busca un vendedor o un objeto.
- `/mercader mapa on|off` muestra u oculta las marcas del mapa.
- `/mercader rumores` trae de vuelta los rumores que ocultaste.
- `/mercader zonas` lista las zonas de la lista propia con el nombre que les da tu cliente, y `/mercader marcas` dice qué está dibujando el mapa (cuántas marcas, para cuántos vendedores): sirven para revisar que la lista coincide con el juego.
- `/mercader minimapa on|off` (y `juntar on|off`: un solo botón para toda la familia de addons), `/mercader idioma es|en|auto`, `/mercader errores`.

## Qué anota

Solo lo que el vendedor tiene en **stock limitado**: lo que siempre está no es un hallazgo. Los tipos sirven para filtrar:

| Tipo | Qué entra (siempre de stock limitado) |
|---|---|
| Equipo | Armas y armaduras (las verdes de las que el vendedor tiene dos) |
| Pociones | Pociones, elixires y frascos |
| Recetas | Recetas |
| Bolsas | Bolsas y carcajes |
| Otros | Cualquier otro objeto |

El stock limitado es el que informa el propio juego en la ventana del vendedor. Un objeto limitado que ya no está en la ventana queda anotado como **agotado** (para que sepas que ahí se vende); un vendedor que solo vende pan y agua no se anota.

Los datos se guardan por cuenta (`MercaderDB`): lo que aprende un personaje lo ven todos. Un vendedor que visitaste con un personaje de una facción no se le muestra a los de la otra, salvo que lo pidas en Opciones.

## De dónde sale la lista de rumores

La armé a mano, objeto por objeto, el 18/11/2026. No copia la base de datos de ningún otro addon.

- **Quién vende qué**: las páginas públicas de objetos de [foreverdb.net](https://foreverdb.net), una consulta por cada uno de los 59 objetos de la lista. Esa página distingue lo que algún jugador ya vio en Forever de lo que todavía es dato de Classic, y Mercader lo dice igual: "otros jugadores vieron este stock en Forever" o "esto viene de Classic y todavía nadie lo confirmó".
- **Dónde**: el pueblo o el lugar que nombra la página de cada vendedor en [warcraft.wiki.gg](https://warcraft.wiki.gg), una consulta por vendedor. La posición es la **del pueblo** (su centro, al punto entero) o, para un vendedor suelto, la que da la página cuando es del mundo viejo; en las ciudades y en las zonas que cambiaron con Cataclysm es la del barrio o el punto de referencia que nombra la página. Por eso el juego dice "por Ratchet (aproximado)". De 64 rumores, 61 tienen posición aproximada (3 de ellos recorren un camino y su marca está sobre ese camino) y 3 solo el lugar.
- Los identificadores de zona siguen la numeración de Classic. foreverdb.net, que saca sus mapas del cliente de Forever, usa esos mismos números (comprobé Durotar 1411, Los Baldíos 1413 y Ventormenta 1453); el resto lo revisa `/mercader zonas` en tu cliente.

Mercader no da nada de esto por cierto: es un punto de partida, y lo que ves vos lo reemplaza.

## Instalar

Copiá la carpeta `Mercader` a `Interface\AddOns\`, dentro de la carpeta de Forever del juego (`World of Warcraft\_forever_\Interface\AddOns`).

## Cómo se probó

**Probado:**
- ✅ Cada función del juego que usa existe en Forever 1.60.1: `tools/check_api.py` contra los dumps de [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) y la UI de [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).
- ✅ [forever-lint](https://github.com/JoseArgento/forever-lint): sin errores. [Addon Sentry](https://github.com/JoseArgento/addon-sentry): "Sin señales de riesgo".
- ✅ **82 tests** en Lua 5.1 (el Lua de WoW) sobre un cliente simulado: qué se anota y qué no, stock que baja y se agota, rumores reemplazados por la visita, facciones, búsqueda por vendedor, objeto y zona, el menú de zonas, marcas agrupadas en la zona y en el continente, las del minimapa (distancia, zoom, minimapa que gira), el libro, el camino marcado, castellano e inglés.
- ✅ Los 59 identificadores de objeto de la lista, uno por uno contra foreverdb.net (un test los fija).

**Visto en el cliente** (Forever 1.60.1, 18/11/2026):
- ✅ El libro: lista, búsqueda, menú de zonas, tipos, idioma, botón único de la familia en el minimapa.
- ✅ Aprender un vendedor al abrir su ventana: stock limitado ("quedaba 1", "quedaban 2"), agotado y precio, tal como lo informa `C_MerchantFrame.GetItemInfo` (en Forever un objeto limitado agotado sigue en la ventana, con 0).
- ✅ El vendedor visitado aparece en el minimapa, y "Marcar camino" responde sin error.

**Todavía sin ver en el cliente ⏳:**
- Las marcas sobre el mapa del mundo. En las primeras pruebas no se veían: quedaban por debajo de la capa de zonas exploradas del juego, que ocupa todo el mapa (los niveles de las marcas del juego arrancan en 2000, según su propio código). Ahora van al nivel de los puntos de interés; `/mercader marcas` dice el nivel y cuántas se dibujaron.
- Las marcas del minimapa en su lugar justo: ahora usan las yardas que informa el juego (`C_Minimap.GetViewRadius`), que también valen adentro de ciudades y edificios.
- El anillo de "Ver mapa" y la página del libro sin vendedor elegido.
- Las posiciones aproximadas de los rumores: salen de la wiki a nivel pueblo o lugar, y las de las ciudades son a nivel barrio. `/mercader zonas` muestra si los identificadores de zona coinciden con el cliente.

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
