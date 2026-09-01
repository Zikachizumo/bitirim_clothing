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
| pantolon | 181 | 202 | %89.6 |
| üst giysi | 478 | 544 | %87.9 |
| ayakkabı | 132 | 151 | %87.4 |
| tişört | 181 | 213 | %85.0 |
| kol (uppr) | 165 | 214 | %77.1 |
| gözlük | 37 | 59 | %62.7 |
| şapka | 136 | 221 | %61.5 |

Eşlenen 1155 parçanın **1149'u render edildi** (%99.5). Kalan 6'sı `A8`
doku formatında — BC1/BC3 dışı, desteklenmiyor.

### Şapka ve gözlük neden geride (çözülmedi)

Bileşenlerde her doku varyantı için ayrı bir `.ytd` dosyası var, o yüzden
dosyadan saymak işe yarıyor. **Prop'larda yaramıyor** — ölçüldü:

    mpbiker anchor 0 (şapka), .ymt'ye göre : [1, 4, 10, 10, 10, 10, 4, ...]
    aynı klasörün .ytd dosyalarından sayım : [7, 10, 1,  1,  1,  1, ...]

Oyun `.ymt`'deki değerleri bildiriyor. `props_ymt.py` bunu okuyor ve
**temel ped tam oturuyor** (n=20, konum 0) — dosya sayımının asla
yapamadığı şey. Ama DLC tarafı hâlâ eksik: ymt'lerden 186 şapka çıkıyor,
oyunda 221 var, ve DLC dizileri listede bulunamıyor.

Muhtemel sebep: aynı klasör için birden çok ymt var (paket + patch'ler) ve
hangisinin geçerli olduğu belirsiz. "En dolu sürümü tut" denendi, değiştirmedi.
Bu yüzden şapka %62, gözlük %66'da duruyor.

### Arşiv gezintisi: nerelere inilmeli

Kapsamayı asıl sınırlayan şey algoritma değil, **dosyaları bulmak**. Hedefli
arama (`hunt_folders.py`) giysilerin dağılımını gösterdi:

- `x64w.rpf > dlc.rpf > mpbeach.rpf` — erken DLC'ler **iki kat** iç içe.
  Tek kat inmek 51 parçayı kaçırıyordu.
- `mppatchesng > mppatches_m_outfits.rpf`, `patchday27ng > patchday27ng_male.rpf`
  — `cdimage` içermeyen adlar.
- Bir parçanın `.ydd`'si ile `.ytd`'si **farklı arşivlerde** olabiliyor
  (`mp2024_02_male.rpf` ↔ `patch2025_01_male.rpf`). Arşiv başına eşleştirmek
  39 parçayı "dokusuz" diye eliyordu; önce global indeks, sonra render.
- `mptuner/dlc.rpf` içinde hiç giysi arşivi **yok** — Enhanced sürümü
  taşımış.

Ama filtresiz inmek de yanlış: tüm iç arşivlere inince (depth<3, filtresiz)
fazladan doku bulunup parmak izi dizisi bozuldu ve kapsama 441'den 331'e
**düştü**. Filtre hedefli olmalı (`_giysi_arsivi` / `_clothing_rpf`).

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
