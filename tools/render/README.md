# Model dosyasından thumbnail render hattı

Mağaza tile'ları için **bedensiz, saydam arka planlı** giysi görselleri üretir.
Oyun içi ekran karesi almaz — GTA'nın kendi `.ydd`/`.ytd` dosyalarını okuyup
çizer.

Bunlar **geliştirme araçlarıdır**, sunucuda çalışmaz. Çıktı PNG'ler
`web/images/` altına gider (git'e girmez).

## Gereksinimler

- Python 3.12 + [fivefury](https://github.com/Hancapo/fivefury) (Unlicense) + numpy
  → bu makinede hazır: `C:\bcc\python\python.exe`
- GTA V kurulumu (`D:\SteamLibrary\...\Grand Theft Auto V Enhanced`)

CodeWalker veya Sollumz **kullanılmıyor** — lisansları uygun değil
(bkz. hafıza: `gta-rage-asset-lisans-durumu`).

## Asıl zorluk: dosya ↔ çalışma zamanı indeksi

Giysiler `x64v.rpf` + 92 DLC paketine dağılmış ve **her paket kendi klasöründe
sıfırdan numaralıyor**. Oyunun verdiği tek liste (üst giysi için 544 drawable)
bunların birleşimi. "Mağazadaki 157 numara hangi dosya?" sorusunun cevabı
hiçbir yerde yazmıyor.

Denenip **başarısız** olan yollar — tekrar denenmesin diye:

| yol | ölçek | sonuç |
|---|---|---|
| dosya adını hash'lemek (9 şema) | 71.847 aday isim | eşleşme yok |
| `.ymt` içindeki hash alanları | 983 ymt, 1592 hedef hash | eşleşme yok |
| `dlclist.xml` sırasıyla saymak | 102 giriş | toplamlar tutmuyor |

Sayılar tutsa bile yeterli olmazdı: "toplam eşit" ≠ "157 numara şu dosya".

## Çalışan yöntem: doku sayısı parmak izi

Oyun her drawable için bir doku sayısı bildiriyor (1..26 arası, epey değişken).
Aynı sayılar dosyalardan da çıkarılabiliyor. İki dizi hizalanıyor.

1. **`/kiyafetdok`** (oyun içi) → `web/dump/male.json`: her drawable için doku
   sayısı + apparel hash.
2. **`align2.py`** → iki geçiş:
   - listede **tek** bir konuma oturan klasörler yerleştirilir
   - kalan boşluklar, yalnızca **tek şekilde** döşenebiliyorsa doldurulur
   - belirsiz hiçbir şey tahminle doldurulmaz
3. **`batch.py`** → eşlenenleri render eder.

Doğrulama (`verify.py`): 157 / 206 / 413 numaralı üst giysiler dosyadan render
edilip oyundan çekilmiş aynı numaralı karelerle karşılaştırıldı — **üçü de
birebir aynı giysi**. Zincir uçtan uca kanıtlandı.

## Kapsama (erkek, 2026-09-01)

| kategori | eşleşen | toplam | oran |
|---|---|---|---|
| ayakkabı | 130 | 151 | %86.1 |
| pantolon | 170 | 202 | %84.2 |
| üst giysi | 447 | 544 | %82.2 |
| kol (uppr) | 163 | 214 | %76.2 |
| tişört | 142 | 213 | %66.7 |
| gözlük | 37 | 59 | %62.7 |
| şapka | 118 | 221 | %53.4 |

Eksiklerin sebebi algoritma değil, **varlık bulma**: bazı DLC'lerin giysi
arşivleri beklenen yerde değil. Örnek: `mptuner/dlc.rpf` içinde hiç giysi
arşivi yok — Enhanced sürümü onları başka yere taşımış. Erken DLC'ler
(mpBeach, mpHipster…) zaten diskte ayrı paket olarak yok.

Eşlenemeyen parçalar **oyun içi karelerini korur** (`/kiyafetcek` çıktısı),
yani hiçbir tile boş kalmaz.

## Ölçülmüş teknik notlar

- **Ped uzayı**: X yanlamasına, Y derinlik, **Z yukarı**. Önden görünüm
  `yaw=180` — `+Y` pedin **arkası**. İki açı yan yana konup boyun oyuntusundan
  doğrulandı.
- **Doku varyantları siluetin kendisini değiştirir.** `jbib_000` için varyant
  `a` (BC3, %30.7 saydam) kolsuz atlet, varyant `b` (BC1, %0 saydam) kollu
  tişört. Aynı mesh, farklı alfa maskesi.
- **`ytd.textures[0]`'a körlemesine düşmek yasak** — gözlük drawable 0 için
  `givemechecker` (eksik doku yer tutucusu) seçilip dama tahtası üretti.
  Doğru doku bulunamazsa hiç üretilmiyor.
- **`read_entry_bytes` yetmez**, `read_entry_standalone` gerekir; yoksa
  fivefury "YDD data must be a standalone RSC7 resource" der.
- **Arşiv gezintisi dar tutulmalı.** Tüm iç arşivlere inince (filtresiz,
  depth<3) klasör adları karıştı ve kapsama 441'den 331'e **düştü**.
- **BC1'in 1-bit saydamlığı**: `c0 <= c1` ise blok 3-renk + saydam modundadır.
  Yok sayılırsa alfa ile kesilmiş parçalar dolu görünür.
- **PNG yazarken satır başına TEK filtre baytı.** `np.concatenate` ile
  `(h,1,ch)` sıfır eklemek `ch` bayt ekler; satır adımı kayar ve görüntü
  kademe kademe ötelenir (yatay şerit gibi görünür).

## Kullanım

```
python tools/render/align2.py  web/dump/male.json  tools/render/map
python tools/render/batch.py   tools/render/map    <çıktı klasörü>
```

`batch.py` var olan PNG'leri atlar, yarıda kalırsa kaldığı yerden devam eder.
