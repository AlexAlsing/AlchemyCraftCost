# AHAlchemyProfit (TBC Classic / Anniversary)

AHAlchemyProfit is a World of Warcraft addon that calculates alchemy crafting profits using **Auctionator SavedVariables loaded in-game**.

It follows this math exactly (all values in copper):

- `craft_cost = sum(mat_qty * mat_price_copper)`
- `sell_price = (preset_value if enabled AND exists) else Auctionator price for output`
- `base_profit_after_cut = sell_price*(1-ah_cut) - craft_cost`
- `expected_profit_after_cut = sell_price*(1+proc_rate)*(1-ah_cut) - craft_cost`

Rounding is done with `math.floor(x + 0.5)` and values are shown in `g/s/c` format.

## Install

1. Download this repo as a zip.
2. Extract and copy the folder `AHAlchemyProfit` into your WoW AddOns folder:

   `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\`

3. Start WoW and enable `AHAlchemyProfit` on character select.

## Usage

- `/ahalchemy` → open/close addon UI
- `/ahap_debug` → print Auctionator DB root keys to chat for schema debugging

### Tabs

- **Calculator**
  - Lists output item, craft cost, sell price, base profit, expected profit, and expected profit %
  - Shows missing prices count (mats/outputs with no found price)
  - Only shows recipes currently enabled in the **Recipes** tab
  - Refresh button recalculates from current Auctionator/preset/settings data

- **Recipes**
  - Shows all tracked crafts with a checkbox per recipe
  - Toggle recipes on/off to control which crafts are included in the Calculator

- **PreValue**
  - Set custom raid-night preset value per item name in g/s/c
  - Save / Remove presets
  - Click a preset row to load it into input fields

- **Settings**
  - Set Proc Rate (default `0.20`)
  - Set AH Cut (default `0.05`)
  - Toggle `Use preset raid-night values` (default `true`)
  - Toggle `Use AtlasLoot elixir materials when available` (default `true`)

## AtlasLoot integration

- On addon load (and when Settings are saved), AHAlchemyProfit attempts to read AtlasLoot tables if AtlasLoot is loaded.
- For recipes with `Elixir` in the output name, the addon tries to replace local material lists with AtlasLoot reagent data.
- If AtlasLoot data cannot be found for a recipe, the existing local material list is kept.

## User action required after update

- Open **Settings** and confirm whether `Use AtlasLoot elixir materials when available` should stay enabled for your setup.
- Open **Recipes** and tick/untick the crafts you want included in profit calculations.

## Included Recipes

- Blinding Light Flask -> Flask of Blinding Light: Mana Thistle x3, Fel Lotus x1, Netherbloom x7
- Flask of Pure Death -> Flask of Pure Death: Mana Thistle x3, Fel Lotus x1, Nightmare Vine x7
- Flask of Fortification -> Flask of Fortification: Mana Thistle x3, Fel Lotus x1, Ancient Lichen x7
- Elixir of Major Mageblood -> Elixir of Major Mageblood: Ancient Lichen x1, Netherbloom x1
- Elixir of Major Shadow Power -> Elixir of Major Shadow Power: Ancient Lichen x1, Nightmare Vine x1
- Elixir of Draenic Wisdom -> Elixir of Draenic Wisdom: Felweed x1, Terocone x1
- Elixir of Major Agility -> Elixir of Major Agility: Terocone x1, Felweed x2

## Notes / troubleshooting

- The addon **does not read files directly**. It only reads Auctionator globals already loaded by WoW.
- Auctionator schema can vary by version. The addon probes common globals:
  - `AUCTIONATOR_PRICE_DATABASE`
  - `AuctionatorPriceDatabase`
  - `AuctionatorDB`
  - `AUCTIONATOR_DB`
- If values look wrong/missing, run `/ahap_debug` and inspect chat output.
- If you change settings or presets, click **Refresh** in Calculator to recompute visible values.
