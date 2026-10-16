# Asset Listesi

Bu dosya `tools/organize_assets.py` ile otomatik uretilir, elle duzenlemeyin.

- Oyunda kullanilacak modeller: `assets/models/<kategori>/`
- Orijinal kaynaklar (sunum icin, Godot import etmez): `assets/_kaynak/`
  - `kaykit_city_builder_bits/`, `kaykit_forest_nature/`: hazir asset paketleri
  - `ai_uretim/`: yapay zeka ile uretilen modeller

## Ozet

| Kaynak | Lisans | Model sayisi |
|---|---|---|
| KayKit City Builder Bits 1.0 (Kay Lousberg) | CC0 | 41 |
| KayKit Forest Nature Pack 1.0 (Kay Lousberg) | CC0 | 105 |
| Yapay zeka ile uretildi (Claude, tools/asset_gen) | Proje ekibine ait | 69 |

**Toplam: 215 model**

## Godot notlari

- `.gltf` dosyalarini sahneye surukleyin; Godot 4 otomatik import eder. Tum sehir modelleri tek doku (`citybits_texture.png`) kullanir, ayni stilde gorunur.
- Olcek: bir karo 2x2 birim, kat yuksekligi ~0.7. Binalar ve karolar y=0'dan baslar (ust yuzey y=0.1). Araclar KayKit arabalari gibi yol karosunun ustune y=0.161'e konur.
- On yon +Z. Arac tekerlekleri ayri node (`*_wheel_*`) -> dondurulebilir. `car_cranetruck_boom` vinc kolu da ayri node.
- `billboard_screen` ve `building_news_screen` ayri node: kendi kampanya gorselinizi material_override ile verin.
- `flood_water_overlay`: herhangi bir karonun ustune koyup y'sini artirarak sel yukselme animasyonu yapilabilir.
- Konut zinciri: `house_lv0_gecekondu` -> `house_lv1` -> `house_lv2` -> `house_lv3`. Her seviyenin `_damaged` ve `_collapsed` hali var; lv1/lv2 icin `_kacak` (kacak kat) ve `_reinforced` (guclendirilmis) versiyonlari var.
- Modelleri yeniden uretmek: `python tools/asset_gen/models.py` sonra `python tools/organize_assets.py`.
- Onizleme: `python -m http.server 8765` -> http://localhost:8765/tools/preview/index.html

## araclar (12)

Arabalar ve acil durum araclari (tekerlekler ayri node)

| Model | Kaynak |
|---|---|
| `car_hatchback` | KayKit City Builder Bits 1.0 |
| `car_police` | KayKit City Builder Bits 1.0 |
| `car_sedan` | KayKit City Builder Bits 1.0 |
| `car_stationwagon` | KayKit City Builder Bits 1.0 |
| `car_taxi` | KayKit City Builder Bits 1.0 |
| `car_afad_rescue` | AI uretimi |
| `car_ambulance` | AI uretimi |
| `car_bus` | AI uretimi |
| `car_cranetruck` | AI uretimi |
| `car_dumptruck` | AI uretimi |
| `car_firetruck` | AI uretimi |
| `car_tv_van` | AI uretimi |

## binalar/konut (18)

Konut zinciri: gecekondu -> lv1 -> lv2 -> lv3, kacak kat, guclendirilmis, hasarli, yikik

| Model | Kaynak |
|---|---|
| `house_lv0_gecekondu` | AI uretimi |
| `house_lv0_gecekondu_collapsed` | AI uretimi |
| `house_lv0_gecekondu_damaged` | AI uretimi |
| `house_lv1` | AI uretimi |
| `house_lv1_collapsed` | AI uretimi |
| `house_lv1_damaged` | AI uretimi |
| `house_lv1_kacak` | AI uretimi |
| `house_lv1_kacak_damaged` | AI uretimi |
| `house_lv1_reinforced` | AI uretimi |
| `house_lv2` | AI uretimi |
| `house_lv2_collapsed` | AI uretimi |
| `house_lv2_damaged` | AI uretimi |
| `house_lv2_kacak` | AI uretimi |
| `house_lv2_kacak_damaged` | AI uretimi |
| `house_lv2_reinforced` | AI uretimi |
| `house_lv3` | AI uretimi |
| `house_lv3_collapsed` | AI uretimi |
| `house_lv3_damaged` | AI uretimi |

## binalar/kamu (8)

Belediye (3 seviye), hastane, itfaiye, okul, AFAD, gazete/TV

| Model | Kaynak |
|---|---|
| `building_afad` | AI uretimi |
| `building_firestation` | AI uretimi |
| `building_hospital` | AI uretimi |
| `building_news` | AI uretimi |
| `building_school` | AI uretimi |
| `building_townhall_lv1` | AI uretimi |
| `building_townhall_lv2` | AI uretimi |
| `building_townhall_lv3` | AI uretimi |

## binalar/ticari (16)

KayKit hazir binalari (dukkan/apartman)

| Model | Kaynak |
|---|---|
| `building_A` | KayKit City Builder Bits 1.0 |
| `building_A_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_B` | KayKit City Builder Bits 1.0 |
| `building_B_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_C` | KayKit City Builder Bits 1.0 |
| `building_C_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_D` | KayKit City Builder Bits 1.0 |
| `building_D_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_E` | KayKit City Builder Bits 1.0 |
| `building_E_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_F` | KayKit City Builder Bits 1.0 |
| `building_F_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_G` | KayKit City Builder Bits 1.0 |
| `building_G_withoutBase` | KayKit City Builder Bits 1.0 |
| `building_H` | KayKit City Builder Bits 1.0 |
| `building_H_withoutBase` | KayKit City Builder Bits 1.0 |

## binalar/insaat (4)

Iskele, insaat alani, kule vinc (yukseltme sirasinda)

| Model | Kaynak |
|---|---|
| `building_construction` | AI uretimi |
| `scaffold_2floor` | AI uretimi |
| `scaffold_4floor` | AI uretimi |
| `tower_crane` | AI uretimi |

## binalar/hasar (3)

KayKit binalarinin hasarli hali + genel yikik bina

| Model | Kaynak |
|---|---|
| `building_A_damaged` | AI uretimi |
| `building_C_damaged` | AI uretimi |
| `building_collapsed` | AI uretimi |

## afet (15)

Moloz, yangin, duman, kum torbasi, cadir, tabelalar, siren, deprem cantasi...

| Model | Kaynak |
|---|---|
| `aid_pallet` | AI uretimi |
| `assembly_area_marker` | AI uretimi |
| `earthquake_kit` | AI uretimi |
| `fire_large` | AI uretimi |
| `fire_small` | AI uretimi |
| `first_aid_box` | AI uretimi |
| `road_barrier` | AI uretimi |
| `rubble_large` | AI uretimi |
| `rubble_small` | AI uretimi |
| `sandbag_wall` | AI uretimi |
| `sign_assembly_area` | AI uretimi |
| `siren_pole` | AI uretimi |
| `smoke_column` | AI uretimi |
| `tent_disaster` | AI uretimi |
| `traffic_cone` | AI uretimi |

## medya_kampanya (4)

Reklam panolari, gazete bayii (farkindalik kampanyalari)

| Model | Kaynak |
|---|---|
| `billboard` | AI uretimi |
| `billboard_campaign` | AI uretimi |
| `newspaper_kiosk` | AI uretimi |
| `newspaper_stack` | AI uretimi |

## yol_zemin (17)

Yollar, kaldirim, cim, su, dere, catlak/sel basmis karolar

| Model | Kaynak |
|---|---|
| `base` | KayKit City Builder Bits 1.0 |
| `road_corner` | KayKit City Builder Bits 1.0 |
| `road_corner_curved` | KayKit City Builder Bits 1.0 |
| `road_junction` | KayKit City Builder Bits 1.0 |
| `road_straight` | KayKit City Builder Bits 1.0 |
| `road_straight_crossing` | KayKit City Builder Bits 1.0 |
| `road_tsplit` | KayKit City Builder Bits 1.0 |
| `flood_puddles_overlay` | AI uretimi |
| `flood_water_overlay` | AI uretimi |
| `road_straight_cracked` | AI uretimi |
| `road_straight_flooded` | AI uretimi |
| `tile_grass` | AI uretimi |
| `tile_grass_flooded` | AI uretimi |
| `tile_plaza` | AI uretimi |
| `tile_river_corner` | AI uretimi |
| `tile_river_straight` | AI uretimi |
| `tile_water` | AI uretimi |

## sokak (13)

KayKit sokak objeleri (bank, lamba, cop kutusu...)

| Model | Kaynak |
|---|---|
| `bench` | KayKit City Builder Bits 1.0 |
| `box_A` | KayKit City Builder Bits 1.0 |
| `box_B` | KayKit City Builder Bits 1.0 |
| `bush` | KayKit City Builder Bits 1.0 |
| `dumpster` | KayKit City Builder Bits 1.0 |
| `firehydrant` | KayKit City Builder Bits 1.0 |
| `streetlight` | KayKit City Builder Bits 1.0 |
| `trafficlight_A` | KayKit City Builder Bits 1.0 |
| `trafficlight_B` | KayKit City Builder Bits 1.0 |
| `trafficlight_C` | KayKit City Builder Bits 1.0 |
| `trash_A` | KayKit City Builder Bits 1.0 |
| `trash_B` | KayKit City Builder Bits 1.0 |
| `watertower` | KayKit City Builder Bits 1.0 |

## doga/agac (20)

Agaclar

| Model | Kaynak |
|---|---|
| `Tree_1_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_1_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_1_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_2_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_2_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_2_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_2_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_2_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_3_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_3_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_3_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_4_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_4_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_4_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_Bare_1_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_Bare_1_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_Bare_1_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_Bare_2_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_Bare_2_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Tree_Bare_2_C_Color1` | KayKit Forest Nature Pack 1.0 |

## doga/cali (22)

Calilar

| Model | Kaynak |
|---|---|
| `Bush_1_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_1_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_1_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_1_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_1_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_1_F_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_1_G_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_2_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_2_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_2_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_2_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_2_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_2_F_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_3_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_3_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_3_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_4_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_4_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_4_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_4_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_4_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Bush_4_F_Color1` | KayKit Forest Nature Pack 1.0 |

## doga/kaya (43)

Kayalar

| Model | Kaynak |
|---|---|
| `Rock_1_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_F_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_G_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_H_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_I_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_J_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_K_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_L_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_M_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_N_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_O_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_P_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_1_Q_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_F_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_G_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_2_H_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_E_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_F_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_G_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_H_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_I_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_J_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_K_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_L_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_M_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_N_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_O_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_P_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_Q_Color1` | KayKit Forest Nature Pack 1.0 |
| `Rock_3_R_Color1` | KayKit Forest Nature Pack 1.0 |

## doga/cimen (20)

Cimen

| Model | Kaynak |
|---|---|
| `Grass_1_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_A_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_B_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_C_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_D_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_Mesh` | KayKit Forest Nature Pack 1.0 |
| `Grass_1_SingleSided_Mesh` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_A_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_A_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_B_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_B_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_C_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_C_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_D_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_D_Singlesided_Color1` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_Mesh` | KayKit Forest Nature Pack 1.0 |
| `Grass_2_SingleSided_Mesh` | KayKit Forest Nature Pack 1.0 |
