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

### Kaynak: ENHANCED kurulum (2026-09-08'den beri)

Önceden Legacy'den render ediliyordu, çünkü sunucu `sv_enforceGameBuild 3323`
ile **Legacy** çalışıyordu. Test sunucusu Enhanced'a taşınınca kaynak da
`Grand Theft Auto V Enhanced` oldu (`GTA_DIR` ile değiştirilebilir).

**Eski "Enhanced'ta bu dört pakette giysi yok" notu yanlıştı.** Sadece
`dlc.rpf`'e bakıldığı için öyle görünmüştü; Enhanced `mptuner` giysilerini
`dlc1.rpf`'te tutuyor (Legacy'de tersi: `dlc.rpf` 3,48 GB + `dlc1.rpf` 47 MB,
Enhanced'ta 1,43 GB + 938 MB). Tüm `dlc*.rpf`'ler tarandığında iki kurulumda
da istenen **1390 parçanın 1390'ı** bulunuyor.

#### İki kurulum ölçüldü, tek anlamlı fark gen9 parçaları

| ölçüm | sonuç |
| --- | --- |
| bulunan parça | 1390 / 1390, ikisinde de |
| doku boyutu + formatı | 12.659 dokunun hepsinde aynı (BC3 1886, BC1 10761, A8 10, BC4 2) |
| damalı yer tutucu doku | ikisinde de tam **519**, aynı (parça, doku) çiftleri |
| render edilen kare | 1384'ün **1076'sı piksel piksel aynı**, 1366'sı gözle ayırt edilemez |
| gerçekten farklı | **18 kare** |

18 farkın 6'sı boş şapka (aşağı bkz.), 12'si küçük renk kayması
(jacket 384 pembe/siyah, 6 tişörtün yaka rengi). shop.meta zaten iki
kurulumda birebir aynıydı (44 dosya, 16.471 kayıt), yani eşleme değişmedi.

### Legacy gen9'a özel parçaları BOŞ KABUK olarak taşıyor

`mp2023_01`, `mp2024_02`, `mp2025_01` ve `*_g9ec` paketlerindeki bazı
parçaların `.ydd`'si Legacy'de **497 bayt** — içinde geometri yok. Enhanced'ta
aynı dosya gerçek mesh (örn. `p_head_003.ydd`: 497 B → 121.330 B).

Kanıt tahmin değil, aynı pakette karşılaştırma: `mpSum2/dlc.rpf` içinde
`mp_m_freemode_01_p_mp_m_sum2/p_head_003.ydd` **117 KB dolu**, ama
`mpSum2_G9EC/dlc.rpf` içindeki `..._sum2_g9ec/p_head_003.ydd` **497 bayt**.
Yani Legacy, gen9'a özel içeriği indeksler kaysın diye boş dosyayla
dolduruyor.

Böyle **87 parça** var: 50 üst giysi, 16 pantolon, 8 ayakkabı, 7 şapka,
6 tişört. Legacy'de render'ları boş çıktığı için kullanıcı listelerinde
"kaldır" işaretlenmişlerdi. Enhanced'a geçince 86'sı `data/removed.lua`'dan
çıkarıldı (`tools/render/restore_g9.py`); HEADWEAR 8 kaldı, çünkü onun
dokuları Enhanced'ta da damalı yer tutucu.

### İki kurulumu karşılaştıran araçlar

```bash
python cmp_index.py map8            # hangi parça hangi kurulumda, .ydd boyutu
python cmp_tex.py  map8 dump/male.json   # doku boyutu/formatı/bayt eşitliği
python diffrank.py out out_enh      # render edilen kareleri piksel piksel
python hunt_file.py p_head_003      # bir dosya adını tüm kurulumda ara
```

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

Tile görseli her zaman doku 0'dan üretiliyordu. Bazı parçalarda doku 0'ın
kendisi dama tahtası çıktı ve katalogdan kaldırıldı — o parçalarda tile de
dama gösteriyordu, üstelik mağazada seçilemeyen bir rengi tanıtıyordu.

Liste artık elle tutulmuyor, `data/removed.lua`'dan **türetiliyor**:
`mk_retile.py` her parça için hayatta kalan en küçük numaralı dokuyu bulur,
0 değilse tile'ı ondan çizdirir. Şu an 9 parça (glasses 1, hat 3/9/10,
jacket 2, pants 2, shoes 0/2/11).

```bash
python mk_retile.py ../../data/removed.lua dump/male.json retile.json
python retile.py map8 retile.json out_enh 512
```

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

### Prop'lar bileşenlerden farklı eksende duruyor

Kamera modelin **Z** eksenini "yukarı" kabul ediyor. `jbib`/`lowr`/`feet` için
bu doğru, ama `p_head`/`p_eyes` için değil — şapkalar ve gözlükler **yan
yatıyordu** (gözlüklerin iki camı yan yana değil alt alta çıkıyordu).

Prop'un kendi **X** ekseni yukarıyı gösteriyor. Doğru dönüşüm:

```
yeni_x = -eski_z     yeni_y = eski_y     yeni_z = eski_x
```

`render_ydd.PROP_BASIS` bunu tutar, `basis_for(prefix)` `p_` ile başlayan
öneklerde uygular. Açı yine `yaw=180` — bileşenlerle aynı önden görünüm.

Nasıl bulundu: bir fötr şapka 24 dönme kombinasyonunda (determinantı +1 olan
bütün eksen permütasyonları) render edilip gözle seçildi, sonra kova şapka,
ekose fötr ve iki gözlükle doğrulandı; ayrıca yaw 0/90/180/270 karşılaştırıldı.

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
