# bitirim_clothing — Tasarım

## 1. Kategori → GTA hedefi eşlemesi

Ekran görüntülerindeki 6 kategori. **Bu tablo uydurulmadı** —
`bitirim_inventory/data/bitirim_clothing.lua` içindeki, oyunda test edilmiş
eşlemenin aynısı; iki resource'un aynı sayıları kullanması zorunlu.

| UI kategorisi | tür | id | native | envanter slot anahtarı |
|---|---|---|---|---|
| HEADWEAR  | prop      | 0  | `SetPedPropIndex` / `ClearPedProp`   | `hat` |
| GLASSES   | prop      | 1  | `SetPedPropIndex` / `ClearPedProp`   | `glasses` |
| OUTERWEAR | component | 11 | `SetPedComponentVariation`           | `jacket` |
| T-SHIRTS  | component | 8  | `SetPedComponentVariation`           | `tshirt` |
| PANTS     | component | 4  | `SetPedComponentVariation`           | `pants` |
| SHOES     | component | 6  | `SetPedComponentVariation`           | `shoes` |

Sağdaki sütun kritik: mağaza envantere `metadata.wear.slot` yazarken **bu
anahtarları** kullanmak zorunda, yoksa envanter parçayı tanımaz.

### Kol (component 3) problemi

GTA'da üst giysi (11) tek başına yetmez; uyumsuz bir kol (component 3) omuzda
ten görünmesine yol açar. Envanter tarafında bu zaten çözülmüş
(`defaultArms`, erkek için ölçülmüş değer `drawable = 135`; kadın **henüz
ölçülmedi**). Mağaza da aynı davranmalı:

1. Parçanın kendi kol kaydı varsa (`wear.arms`) onu uygula.
2. Yoksa oyunun zorunlu-bileşen verisinden otomatik eşleşen kolu al.
3. O da yoksa `defaultArms`'a düş.

Bu üçlü mantık mağaza ile envanterde **birebir aynı** olmalı, aksi halde
oyuncu mağazadan çıkınca görüntü değişir.

## 2. Katmanlar

```
server.lua          satın alma otoritesi: fiyat doğrula, parayı al,
                    envantere `apparel` item'ı + metadata yaz
  │
  ├─ config/config.lua    kategoriler, fiyatlar, slot eşlemesi
  ├─ config/coords.lua    NPC konumu, önizleme ışınlanma noktası, interior ankor
  │
client.lua          NPC + E etkileşimi, NUI aç/kapa, ışınlanma
  ├─ catalog.lua     ÇALIŞMA ANI katalog taraması (bkz. CATALOG.md)
  ├─ preview.lua     3D önizleme: ped'e geçici uygula, kamera çerçevele, döndür
  └─ web/            React NUI (bkz. UI-SPEC.md)
```

**Server otoritesi şart.** Client sadece "şu kategoriden şu drawable/texture'ı
aldım" der; fiyatı ve satın almayı server doğrular. Client'a fiyat hesaplatmak
para basma açığıdır.

## 3. Veri akışı

```
oyuncu NPC'ye E basar
  → client: oyuncuyu önizleme noktasına ışınla, kamerayı kur, NUI aç
  → client: katalog taramasını çalıştır (ilk açılışta, sonra cache)
  → NUI: kategori listesi
oyuncu kategoriye girer
  → NUI: o kategorinin drawable listesi (tile başına 1 drawable)
  → client: kamerayı kategoriye göre çerçevele (kafa / gövde / bacak / ayak)
oyuncu tile'a tıklar
  → client: ped'e GEÇİCİ uygula (satın alma yok, sadece görüntü)
oyuncu ADD TO CART der
  → NUI: sepete ekle (client tarafı liste)
oyuncu satın alır
  → server: fiyat doğrula → parayı al → envantere `apparel` + metadata.wear
  → client: ped'i oyuncunun GERÇEK envanter görünümüne geri döndür
```

Son satır önemli: mağaza ped'e sadece **önizleme** uygular. Kalıcı görünümün
tek sahibi envanterin `equipment_client.lua`'sı. Mağaza kapanınca envanterin
uyguladığı hale dönülür, yoksa iki sistem birbirini ezer.

## 4. bitirim_inventory entegrasyonu

Satın alınan parça envantere şu formatta yazılır (envanterin `resolvePiece`
fonksiyonunun **yeni ve tercih edilen** formatı):

```lua
item     = 'apparel'
metadata = {
    wear     = { slot = 'jacket', drawable = 12, texture = 3 },
    label    = 'Mont',
    imageurl = 'nui://bitirim_clothing/web/images/jacket_12_3.png',
}
```

- `wear.slot` → bölüm 1'deki sağ sütun anahtarları
- `imageurl` → **tam URL**; envanter paneli `image`'den önce buna bakar
- Eski `clothing` item'ı geriye uyumluluk için envanterde hâlâ destekleniyor,
  yeni satışlarda kullanılmaz

## 5. Underwear senkronu

Envanterde boş slot **çıplak değil underwear'a** düşer
(`data/bitirim_clothing.lua` → `underwear` tablosu, kaynağı illenium
`Config.InitialPlayerClothes`). Mağazanın `Config.Underwear`'ı bu tabloyla
**senkron** olmak zorunda: oyuncu mağazada bir parçayı çıkarıp baktığında
gördüğü taban ile envanterden çıkardığında gördüğü taban aynı olmalı.

## 6. Cinsiyet

`mp_m_freemode_01` ve `mp_f_freemode_01` için drawable sayıları **ve
indekslerin anlamı** farklıdır — erkekteki 135 kadında bambaşka bir parçadır.
Katalog her cinsiyet için ayrı taranır, ayrı cache'lenir, thumbnail'lar ayrı
üretilir. Ekran görüntülerindeki `CLOTHING / MENS` kırılımı bu.
