# Chains - Skillchains Reborn

Active Battle Skillchain Display for Ashita v4.

Originally based on the `skillchains` addon by **Ivaar** (Ashita v3) and modernized by **NerfOnline / Sippius**.  
This edition features a completely overhauled dark HUD layout with hierarchical skillchain trees, visual timing gauges, and full Japanese property support tailored for private servers (tested on HorizonXI) and retail.

---

## Key Features & UI Improvements

- **Streamlined Dark HUD**:
  - Semi-transparent dark palette with soft-rounded corners (6px).
  - Clear state headers displaying action phase (`ACT`, `WAIT`, `BURST`), timing, and step count.
- **Fixed 7-Block Timing Slider**:
  - Displays remaining skillchain window duration via a visual block countdown gauge.
  - Linear 1-second countdown for `WAIT` delays and proportional slide decay for `ACT` windows.
- **Hierarchical Tree View**:
  - Weaponskills and spells grouped cleanly by resulting skillchain property.
  - Indented structure for fast parent-child visual navigation during combat.
- **Bilingual & Japanese Property Support**:
  - Japanese skillchain properties (e.g., `核熱`, `衝撃`) highlighted with distinct elemental colors alongside subdued English labels (`[Fusion]`, `[Reverberation]`).
  - Magic Burst (MB) affinities tokenized alongside the starter skill.
- **HorizonXI Compatibility**:
  - Packet handling and delay calculations adjusted and tested for classic/private server environments (including Pet, BLU, and SCH actions).

---

## Recommended Font

For optimal alignment and readability, **`MyricaM M`** (or `Myrica M`) is strongly recommended.  
If installed in Windows (`C:\Windows\Fonts`), Chains will automatically load it with full Japanese glyph support.

---

## Commands

### Window Positioning & Display
- `/chains visible` — Toggle preview window with drag handle to position on screen.
- `/chains test` — Toggle test dummy skillchain preview.
- `/chains direction` — Toggle anchor direction (`top` / `bottom`).
- `/chains reset` — Reset window position to default coordinates.

### Content Toggles
- `/chains color` — Toggle colorized properties and elements.
- `/chains weapon` — Toggle weaponskill suggestions.
- `/chains spell` — Toggle SCH Immanence and BLU magic spells.
- `/chains pet` — Toggle SMN and BST pet skills.

---

## Original Features & Heritage

- **IMGUI-Based Rendering**: Real-time recalculation per render frame based on equipped gear and active buffs.
- **Ability Context Awareness**: BLU and SCH spells display dynamically when corresponding abilities (Immanence, Chain Affinity, Azure Lore) are active.
- **Pet & NPC WS Support**: Tracks avatars, automatons, and party skills.
- **Aeonic Weapon Support**: Logic included for ultimate skillchains (Radiance/Umbra).

---

## Known Issues & Limitations

- Chain Affinity requires BLU main for full buff tracking.
- Azure Lore duration assumes standard 30-second duration without relic hand adjustment.
- Cannot automatically detect when another player manually cancels an ability buff.

---

## Acknowledgments & Credits

- **Ivaar**: Original author of the `skillchains` addon for Ashita v3.
- **Sippius & NerfOnline**: Ported and restructured core logic for Ashita v4.
- **Atom0s & Thorny**: Foundation libraries, Ashita v4 framework, and coding examples.
- **purya-mochi**: HUD overhaul, 7-block slider gauge implementation, tree layout, and Japanese localization.
