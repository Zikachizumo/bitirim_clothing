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

## ASIL KAYNAK: GTA'nın kendi mağaza verisi

`mp_m_freemode_01_<dlc>_shop.meta` — GTA Online'ın kıyafetçi menüsünün
kaynağı. Erkek için **44 dosya, 16.471 kayıt**. Her kayıtta:

| alan | ne verir |
|---|---|
| `uniqueNameHash` | `DLC_MP_BIKER_M_JBIB_21_0`; joaat'ı = oyunun bildirdiği apparel hash'i |
| `localDrawableIndex` / `localPropIndex` | DLC içindeki dosya numarası |
| `textureIndex` | doku varyantı |
| `eCompType` / `eAnchorPoint` | bileşen veya prop slot'u |
| `textLabel` | parçanın gerçek adı (GXT anahtarı) |
| `cost` | Rockstar fiyatı — **%80'i 0, kullanışsız** |
| `forcedComponents` | kol uyumluluğu |

Yani "mağazadaki 157 numara hangi dosya" sorusunun cevabı burada **yazıyor**.
Çıkarım yok. `shopmeta.py` ayrıştırır, `crosscheck.py` eşlemeyi kurar.

İki tuzak (ölçüldü):
- `<Item>` etiketleri **iç içe** (`restrictionTags` içinde de var). Basit
  `<Item>(.*?)</Item>` non-greedy regex ilk kapanışta kesiyor ve
  `localDrawableIndex` kayboluyor: 16.471 yerine ~50 kayıt çıkıyordu.
  Derinlik sayarak ayırmak gerekiyor.
- **Prop'lar farklı alan adı kullanıyor**: bileşenler `localDrawableIndex`,
  prop'lar `localPropIndex`. Sadece ilkine bakmak şapka/gözlük eşlemesini
  sıfır bırakıyordu.

## Doğrulama: iki bağımsız yöntem

Parmak izi yöntemi (aşağıda) çıkarımdır, shop.meta doğrudan veridir. Çakıştıkları
**1133 parçanın 1131'inde ikisi aynı şeyi söylüyor**. 2 çelişki çıktı (şapka
195–196) ve orada shop.meta doğru kabul edildi — çıkarım değil, tablo.

Bu karşılaştırmanın kendisi değerli: sessiz kalacak bir hatayı yakaladı.

## Yedek yöntem: doku sayısı parmak izi

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

## Kapsama (erkek, 2026-09-02)

| kategori | eşleşen | toplam | oran |
|---|---|---|---|
| üst giysi | 544 | 544 | **%100** |
| tişört | 213 | 213 | **%100** |
| pantolon | 202 | 202 | **%100** |
| ayakkabı | 151 | 151 | **%100** |
| şapka | 221 | 221 | **%100** |
| gözlük | 59 | 59 | **%100** |
| kol (uppr) | 198 | 214 | %92.5 (mağazada gösterilmiyor) |

Sunucuda **1384 render, 0 oyun karesi**. Mağazadaki her tile artık model
dosyasından çizilmiş, saydam zeminli bir parça.

Eşlenen 1390 parçanın 1384'ü render edildi. Kalan 6'sı boş yer tutucu
(bkz. aşağıda) ve katalogdan çıkarıldı.

### KÖK SEBEP: bir pakette birden fazla `dlc*.rpf` olabilir

Uzun süre "tuner / battle / heist4 / security DLC'lerinin erkek giysileri bu
oyun sürümünde yok" sanıldı — 132 parça bu yüzden render edilemiyordu.
Yanlıştı. O dört paket giysilerini **`dlc1.rpf` ve `dlc2.rpf`** içinde
tutuyor, tarayıcı ise yalnızca `dlc.rpf`'i açıyordu:

```
mpbattle/   dlc.rpf  dlc1.rpf
mpheist4/   dlc.rpf  dlc1.rpf  dlc2.rpf
mpsecurity/ dlc.rpf  dlc1.rpf
mptuner/    dlc.rpf  dlc1.rpf
```

Oyunun tamamında sadece bu dört pakette var. Düzeltince `mp_m_tuner`
klasöründe görünen dosya sayısı 10'dan 94'e, `mp_m_heist4` 7'den 59'a çıktı.

**Ders:** "paket = dlc.rpf" bir varsayımdı ve dört yerde yanlıştı. Paket
klasöründeki `dlc*.rpf` dosyalarının hepsi açılmalı.

### Kaynak: Legacy kurulum, Enhanced değil

Sunucu FiveM **b3323** üzerinde çalışıyor, o da **Legacy** GTA V'i kullanıyor;
araçlar artık `Grand Theft Auto V` klasörünü okuyor (`GTA_DIR` ile
değiştirilebilir). Enhanced kurulumu bu dört pakette giysi arşivi hiç
içermiyor — `mptuner/dlc.rpf` içinde `mptuner_female.rpf` var ama erkek
karşılığı yok.

shop.meta iki kurulumda birebir aynı çıktı (44 dosya, 16.471 kayıt), yani
daha önce Enhanced'dan kurulan eşleme geçerliliğini koruyor.

### shop.meta'nın kapsamadığı 12 parça

12 parçanın apparel hash'i 16.471 kaydın hiçbirinde yok — GTA Online'da
mağazadan satılmıyorlar. Üç kısıtın kesişimiyle çözüldüler
(`tools/render/extra_map.py`):

1. boşluk, eşlenmiş komşuları arasında → hangi DLC aralığına düştüğü belli
2. o dönemin **kullanılmayan** dosyaları sayılı (tam indeksten çıkarıldı)
3. oyunun bildirdiği doku sayısı = dosyanın doku varyantı sayısı

Gözlük 23 için özellikle güçlü: oyunun tamamında kullanılmayan **tek bir**
`p_eyes` dosyası var. Yine de hepsi oyun içi karelerle görsel olarak
karşılaştırıldı — şapka 61 (yeşil bantlı siyah fötr), şapka 64 (mavi ekose
fötr), ayakkabı 17 (kırmızı-yeşil elf ayakkabısı) ve ayakkabı 40 (mavi
spor ayakkabı) birebir tuttu.

### Dama tahtası tespiti: bayt eşitliği

Rockstar'ın eksik-doku yer tutucusu oyunun **her yerinde aynı dosya**:
64x64 BC1, 2728 bayt, `sha1 cf8ff45d653c…`. `find_checker.py` her dokunun ham
baytlarını hash'ler ve aynı hash'i paylaşanları gruplar. Gerçek bir giysi
dokusu yer tutucuyla bayt bayt aynı olamaz — **yanlış pozitif imkânsız**.

Erkek tarafında **503 doku, 53 parça**. Altısında bütün renkler yer tutucu.

Denenip yetersiz kalan ölçütler:

| ölçüt | sonuç |
|---|---|
| benzersiz renk sayısı < 8 | **çalışmadı** — BC1 + gölgelendirme, iki renkli bir damayı 671 renge çıkarıyor |
| boyut oranı ≤ 1/16 | 423 buldu, **80'ini kaçırdı** — parçanın bütün varyantları yer tutucuysa kıyas edilecek büyük yok |
| bayt eşitliği | **503, tam** |

Ayrıca 12.651 render "dama benzerliği" puanıyla sıralandı (ikilileştirilmiş
parlaklıkta komşu piksel işaret değişimi oranı) ve en yüksek 120'si tek tek
incelendi: hepsi **gerçek desenli giysi** (ekose, puantiye, zebra,
balıkkılcığı). Bayt eşitliğinin kaçırdığı dama tahtası yok.

### Tile görseli hayatta kalan dokudan

Tile görseli her zaman doku 0'dan üretiliyordu. 11 parçada doku 0'ın kendisi
dama tahtası çıktı — o parçalarda tile de dama gösteriyordu. `retile.py`
onları hayatta kalan ilk dokudan yeniden çizer.

### Boş yer tutucular (6 parça, katalogdan çıkarıldı)

`data/removed.lua` (`'bos'` sebebiyle). Bunlar oyunun listesinde görünen ama giyilince ekranda
hiçbir şey göstermeyen parçalar. İki bağımsız ölçüm:

- tek dokuları **4x4 `A8`** yer tutucu (gerçek parçalar 512x512 BC1/BC3)
- `/kiyafetcek` kareleri boş: ayakkabı yerine çıplak ayak, şapka yerine
  kel kafa, gözlük yok, üst giysi yok

Satın alınabilir bir şey olmadıkları için katalogdan tamamen çıkarıldılar.

### Aynı isimli dokunun çözülemeyen kopyası

`mptuner` içinde `feet_diff_002_a_uni` hem BC4 hem BC1 olarak var (patch ile
gelen kopya + asıl). İlk bulunanı kullanmak render'ı patlatıyordu. `batch.py`
artık bir parçanın bütün doku adaylarını topluyor ve çözülebilen ilkini
kullanıyor.

### Prop'larda doku sayısı parmak izi neden zayıf

Bileşenlerde her doku varyantı için ayrı bir `.ytd` dosyası var, o yüzden
dosyadan saymak işe yarıyor. **Prop'larda yaramıyor** — ölçüldü:

    mpbiker anchor 0 (şapka), .ymt'ye göre : [1, 4, 10, 10, 10, 10, 4, ...]
    aynı klasörün .ytd dosyalarından sayım : [7, 10, 1,  1,  1,  1, ...]

Oyun `.ymt`'deki değerleri bildiriyor. `props_ymt.py` bunu okuyor ve temel
ped tam oturuyor (n=20, konum 0), ama DLC tarafı eksik kalıyor — aynı klasör
için birden çok ymt var (paket + patch'ler) ve hangisinin geçerli olduğu
belirsiz.

Bu yüzden şapka/gözlük parmak izi %62-68'de takılıyordu. **Sorun shop.meta
ile çözüldü** (%100); parmak izi artık yalnızca çapraz doğrulama için
kullanılıyor.

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
- `mptuner/dlc.rpf` içinde giysi arşivi **yok** — ama paket eksik değil,
  giysiler `mptuner/dlc1.rpf`'te. Bkz. yukarıdaki kök sebep bölümü.

Ama filtresiz inmek de yanlış: tüm iç arşivlere inince (depth<3, filtresiz)
fazladan doku bulunup parmak izi dizisi bozuldu ve kapsama 441'den 331'e
**düştü**. Filtre hedefli olmalı (`_giysi_arsivi` / `_clothing_rpf`).

Artık eşlenemeyen parça yok; mağazadaki bütün görseller model dosyasından
geliyor. `/kiyafetcek` (oyun içi kare alma) yalnızca doğrulama aracı olarak
duruyor.

## Renk (doku) varyantlarının render'ı

Mağazadaki sağ üst renk menüsü her varyantın kendi render'ını gösteriyor.
`tools/render/batch_tex.py` üretir:

```
python tools/render/batch_tex.py  tools/render/map_final  web/dump/male.json  <çıktı>  80
```

Çıktı `<slot>_<drawable>_<doku>.png`, 80x80, saydam. Erkek tarafı için
**12.705 varyant** (~86 MB) — sunucuda `web/images/tex/` altında.

Bu sadece renk meselesi değil: **doku varyantı siluetin kendisini
değiştirebiliyor.** `jbib_000` varyant `a` kolsuz atlet, varyant `b` kollu
tişört — aynı mesh, farklı alfa maskesi. Yani "aynı parça farklı renk"
varsayımı yanlış.

### Harf ↔ doku indeksi

Dosyalar varyantı harfle adlandırıyor (`jbib_diff_000_a_uni`), oyun ise
indeksle (`texture 0`). Eşleme ölçüldü:

- 1390 parçanın **1390'ında** harf dizisi kesintisiz `a, b, c…` gidiyor
- 1382'sinde oyunun bildirdiği doku sayısı = dosya sayısı (8 şapkada dosya
  fazla, oyun daha azını gösteriyor — fazlalar kullanılmıyor)
- `a = 0` bağımsız olarak doğrulandı: oyun içi kareler doku 0 ile çekilmişti
  ve `a` varyantından render edilenlerle birebir tutmuştu (`verify.py`,
  drawable 157/206/413)

### Materyal her zaman `a`'yı gösterir

Mesh'in materyalinde yazan doku adı hep `..._a_uni`. `b` varyantının
`.ytd`'sinde ise doku `..._b_uni` adıyla duruyor, yani ad eşitliği tutmaz ve
"dosyadaki tek gerçek diffuse" kuralına düşülür. Yanlış varyant seçme riski
olmasın diye `render_ydd.render()` artık `prefer=` ile doğru adı dışarıdan
alıyor.

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

Oyun içi dökümden başlayıp mağaza görsellerine kadar:

```
# 1) oyunda:  /kiyafetdok        -> web/dump/male.json
python tools/render/shopmeta.py   mp_m_freemode_01     meta/     # GTA magaza verisi
python tools/render/align2.py     web/dump/male.json   map/      # parmak izi (dogrulama)
python tools/render/crosscheck.py web/dump/male.json        meta/shopmeta_mp_m_freemode_01.json  map/  map_merged/    # ikisini birlestir
python tools/render/extra_map.py                                 # shop.meta'siz 12 parca
python tools/render/batch.py      map_final/  out/               # 512x512 render
python tools/render/downscale.py  out/        out256/            # 256x256 tile
```

`batch.py` var olan PNG'leri atlar, yarıda kalırsa kaldığı yerden devam eder.
Kaynak kurulum `GTA_DIR` ile değiştirilebilir (varsayılan: Legacy).
`fullindex.py` ise bütün arşivleri filtresiz gezip dosya envanteri çıkarır —
"bu klasörde hangi dosyalar var" sorusunu cevaplamak için.
