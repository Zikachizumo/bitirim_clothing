# bitirim_clothing — NUI Spec

Referans: 2026-09-01'de oyundan alınan 7 ekran görüntüsü. Aşağıdakiler o
görüntülerden **okunan** değerler, tahmin değil.

## Genel yerleşim

- Ekranın **sol ~%29'u** panel, kalanı oyun görüntüsü (ped canlı görünür).
- Panel arkaplanı koyu, oyunun üstüne biner; sağ taraf **hiç kaplanmaz** —
  oyuncu kendini net görür.
- Sağ üst: `CLOSE` + `ESC` rozet.
- Sol alt: fare ikonu + `TURN CHARACTER` (iki satır, ikinci satır ikinci kelime).
- Kategori ekranında sağ alt: sepet ikonu + `THERE ARE NO ITEMS IN THE SHOPPING CART`.

## Ekran 1 — Kök

```
SHOP          (kalın, büyük)
CLOTHES       (ince, açık gri, bir alt satır)

┌──────────────────────────┐
│ HEADWEAR            [🎩] │
│ OUTERWEAR           [🧥] │
│ T-SHIRTS            [👕] │
│ PANTS               [🩳] │
│ SHOES               [👟] │
│ GLASSES             [🕶] │
└──────────────────────────┘
```

Her satır: sol hizalı büyük harf etiket, sağda kategori ikonu, satırlar arası
ince ayraç, hover'da satır aydınlanır.

## Ekran 2 — Kategori

```
[←]                    HEADWEAR  [🎩]

┌────┬────┬────┬────┐   ← 4 sütunlu grid, dikey scroll
│ th │ th │ th │ th │     tile = 1 DRAWABLE
│ ▾ad│ ▾ad│ ▾ad│ ▾ad│     ▾ = texture (renk) varyantları açılır
└────┴────┴────┴────┘
```

Ekranın **alt-orta** kısmında seçili parça kartı (panelin dışında, oyun
görüntüsünün üstünde, ortalanmış):

```
            Mens headwear          ← parça adı, büyük
        ▾ CLOTHING / MENS          ← kırılım, küçük, açık gri

    [−]  1  [+]   [ + ADD TO CART  $600 ]
```

## Kamera çerçeveleme (kategoriye göre)

Bu, tasarımın en belirleyici parçası: kategori değişince kamera parçayı
gösterecek şekilde kayar.

| Kategori | Çerçeve |
|---|---|
| HEADWEAR | kafa yakın plan, omuz üstü |
| GLASSES | kafa yakın plan (headwear ile aynı) |
| OUTERWEAR | gövde, bel üstü — ped hafif yandan |
| T-SHIRTS | gövde, bel üstü — ped cepheden |
| PANTS | bel–ayak bileği arası |
| SHOES | ayaklar, diz altı |

Geçiş ani değil, yumuşak interpolasyon olmalı.

## Fiyatlar (görüntülerden okundu)

| Kategori | Fiyat |
|---|---|
| HEADWEAR | $600 |
| OUTERWEAR | $1 350 |
| T-SHIRTS | $1 000 |
| PANTS | $600 |
| SHOES | $850 |
| GLASSES | $1 000 |

Kategori başına **sabit** fiyat. `config/config.lua`'da tutulur ve satın alma
sırasında **server doğrular**.

> Not: sabit fiyat basit ama ucuz bir tişört ile pahalı bir takım aynı parayı
> ediyor. İstersen ileride drawable aralığına göre kademeli fiyat eklenebilir;
> mevcut tasarım görüntülerdeki davranışı birebir korur.

## Etiketleme

Görüntülerde her parça `Mens headwear`, `Mens outerwear` … yani **kategori adı**
taşıyor; GTA drawable'larının oyun içinde okunabilir bir adı yok. Tasarım bunu
korur. İstenirse `config`'e `overrides` tablosu eklenip seçili parçalara elle
isim verilebilir (ör. drawable 5 → "Dunce Şapkası"), tanımsızlar generic kalır.
