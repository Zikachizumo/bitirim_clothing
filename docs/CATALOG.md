# Katalog taraması ve thumbnail hattı

"Tüm itemleri orijinal kategoriden çek" isteğinin nasıl karşılandığı.

## 1. Neden oyun dosyalarından DEĞİL, çalışma anında

Elimizdeki kurulum: `D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced`
— **92 dlcpack**, bunların **50'si `mp*`** (multiplayer kıyafet taşıyanlar),
`mp2026_01`'e kadar güncel.

Buna rağmen katalog **oyun dosyalarından çıkarılmayacak**. Üç sebep:

1. **Bu bir GTA V *Enhanced* kurulumu.** Enhanced'in RPF'leri farklı
   şifrelenir; CodeWalker/OpenIV desteği burada güvenilir değil. Çıkaramadığımız
   veya yanlış çıkardığımız bir listeye dayanmak, en baştan yanlış katalog demek.
2. **Otorite senin kurulumun değil, sunucunun FiveM sürümü.** Oyuncunun
   gördüğü parçalar sunucunun (ekran görüntüsünde `b3788`) yüklediği DLC'lere
   göre belirlenir. Senin makinendeki dlcpack listesi sunucununkiyle aynı
   olmak zorunda değil — mağaza sunucuda çalışacak.
3. **Sürüm geçtikçe bozulur.** Rockstar yeni DLC attığında dosyadan çıkarılmış
   sabit liste eskir; çalışma anı taraması kendini günceller.

Kurulumun yine de bir işe yarıyor: **thumbnail üretim seansını senin makinende
çalıştırmak** (bölüm 3) ve sunucu–client DLC paritesini karşılaştırmak.

## 2. Tarama (client, açılışta bir kez)

Her kategori için, o cinsiyetin ped'i üzerinde:

**Component'ler** (OUTERWEAR 11, T-SHIRTS 8, PANTS 4, SHOES 6):

```lua
local drawableCount = GetNumberOfPedDrawableVariations(ped, componentId)
for d = 0, drawableCount - 1 do
    local textureCount = GetNumberOfPedTextureVariations(ped, componentId, d)
    for t = 0, textureCount - 1 do
        if IsPedComponentVariationValid(ped, componentId, d, t) then
            -- katalog[componentId][d][#+1] = t
        end
    end
end
```

**Prop'lar** (HEADWEAR 0, GLASSES 1):

```lua
local drawableCount = GetNumberOfPedPropDrawableVariations(ped, propId)
for d = 0, drawableCount - 1 do
    local textureCount = GetNumberOfPedPropTextureVariations(ped, propId, d)
    -- prop'ta IsPed...VariationValid muadili yok; texture sayısı 0 ise atla
end
```

Kurallar:

- **Sayım asla varsayılmaz.** Kaç parça çıktığı taramanın çıktısıdır; bu
  dokümana sabit sayı yazılmaz.
- `IsPedComponentVariationValid` **false** dönen kombinasyon katalogdan düşer —
  geçersiz drawable uygulanırsa ped bozulur.
- Tarama **cinsiyet başına** ayrı yapılır ve cache'lenir; her mağaza
  açılışında tekrar taranmaz.
- Tarama, oyuncunun kendi ped'inde değil **klon ped** üzerinde yapılır ki
  oyuncunun görünümü taranırken titremesin.

## 3. Thumbnail hattı

Grid'de tile başına bir görsel gerekiyor (ekran görüntülerindeki küçük render'lar).
Bunlar canlı 3D değil, **önceden üretilmiş PNG**.

Üretim, tek seferlik bir in-game toplu iş:

1. Boş bir sahnede klon ped + sabit ışık + düz arkaplan kurulur.
2. Kamera kategoriye göre çerçevelenir (UI-SPEC'teki tablo).
3. Katalogdaki her drawable için **ilk geçerli texture** uygulanır.
4. `screenshot-basic` ile kare alınır, lokal bir HTTP alıcıya POST edilir.
5. Alıcı `web/images/<kategori>_<drawable>.png` olarak yazar.

Adlandırma NUI'nin beklediği şema: `jacket_12.png`, `hat_5.png` …
Envantere yazılan `imageurl` de bununla aynı dosyayı gösterir, böylece parça
mağazada ve envanterde **aynı görseli** taşır.

Texture varyantları (tile üzerindeki `▾`) için ayrı PNG üretilmez — varyant
seçimi ped üzerinde canlı görünür; tile görseli drawable'ı temsil eder. Bu,
görsel sayısını texture katına çıkarmadan tutar.

## 4. Sırayla ne yapılacak

1. VPS'ten eski kaynağı geri al (özellikle `config/coords.lua`).
2. `catalog.lua` yaz, `/kiyafettara` gibi bir komutla say ve **gerçek sayıları
   ölç** — sonra bu dokümana yaz.
3. Thumbnail toplu işini bir kez çalıştır, `web/images/` doldur.
4. NUI'yi UI-SPEC'e göre kur.
5. Satın almayı server'a bağla, envanter formatını DESIGN bölüm 4'e göre yaz.
