# AHAlchemyProfit (TBC Classic / Anniversary)

AHAlchemyProfit is a World of Warcraft addon that calculates alchemy crafting profits using **Auctionator SavedVariables loaded in-game**.

It follows this math exactly (all values in copper):

- `craft_cost = sum(mat_qty * mat_price_copper)`
- `sell_price = (preset_value if enabled AND exists) else Auctionator price for output`
- `base_profit_after_cut = sell_price*(1-ah_cut) - craft_cost`
- `expected_profit_after_cut = sell_price*(1+proc_rate)*(1-ah_cut) - craft_cost`

Rounding is done with `math.floor(x + 0.5)` and values are shown in `g/s/c` format.

## Install

Choose **one** of these folder layouts in `Interface/AddOns`:

### Option A (recommended)
1. Download this repo as a zip.
2. Extract and copy the folder `AHAlchemyProfit` into:

   `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\`

3. Start WoW and enable `AHAlchemyProfit` on character select.

### Option B (also supported)
1. Copy the whole repo folder as `AlchemyCraftCost` into `Interface/AddOns`.
2. Keep `AlchemyCraftCost.toc` directly inside that folder root.
3. Start WoW and enable `AHAlchemyProfit` on character select.

> Important: Do **not** copy a nested structure like `Interface/AddOns/AlchemyCraftCost/AHAlchemyProfit/...` unless `AlchemyCraftCost.toc` exists directly in `Interface/AddOns/AlchemyCraftCost/`.
> WoW scans addon folders by checking for `.toc` at the folder root level.

## Faster dev loop (no repeated zip/reinstall)

Use a direct folder link from this repo to your WoW AddOns folder so edits are visible immediately:

1. Keep this repo on your local machine.
2. Remove any old copied `AHAlchemyProfit` folder from `Interface/AddOns`.
3. Create a link from your repo folder to AddOns:

   **Windows (PowerShell as Administrator)**
   ```powershell
   New-Item -ItemType Junction \
     -Path "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\AHAlchemyProfit" \
     -Target "C:\path\to\AlchemyCraftCost\AHAlchemyProfit"
   ```

   **macOS / Linux**
   ```bash
   ln -s /path/to/AlchemyCraftCost/AHAlchemyProfit /path/to/WoW/_anniversary_/Interface/AddOns/AHAlchemyProfit
   ```

4. Edit files in this repo, then in-game run `/reload` to test changes instantly.

Recommended workflow to avoid unnecessary pushes:

- Develop and test locally first (`/reload` after each change).
- Use `/ahap_debug` to verify Auctionator data before committing.
- Commit only when a change is verified in-game.
- Push when a feature/fix is ready, not for every small tweak.

### Will this guarantee fewer problems?

Short answer: **it will make iteration much faster**, but it does not guarantee zero issues.

What this setup solves well:

- No repeated zip export/copy for every small change.
- Faster feedback loop (`save file -> /reload -> verify`).
- Lower risk of testing stale addon files from an old copied folder.

What you still need to verify each test cycle:

1. Run `/reload` after edits.
2. Use `/ahap_debug` if prices are missing or look wrong.
3. Confirm **Recipes** selection and **Settings** toggles are correct for your character/profile.
4. Click **Refresh** in **Calculator** after changing settings/presets.

Quick troubleshooting checklist:

- Ensure there is only one active `AHAlchemyProfit` folder in `Interface/AddOns` (linked folder preferred).
- If `/ahalchemy` does nothing and the addon is missing in AddOn List, verify where the `.toc` file sits: it must be directly inside `Interface/AddOns/<FolderName>/` (not in a subfolder one level deeper).
- If you install as `AddOns/AlchemyCraftCost`, verify `AddOns/AlchemyCraftCost/AlchemyCraftCost.toc` exists.
- Multiple addon folders are fine (for example AtlasLoot modules), but **each folder must have its own `.toc` directly inside that folder** to be discovered by WoW.
- Confirm Auctionator is enabled and has scanned data for your realm/faction.
- If using AtlasLoot mats, verify AtlasLoot is loaded before AHAlchemyProfit data refresh.
- If behavior seems cached, `/reload` once more and retest on a known recipe with stable prices.

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
