# bitirim_clothing

Bitirim RP için kıyafet mağazası (FiveM / Qbox). NPC'ye `E` ile girilir, oyuncu
kendini 3D görerek dener, satın alınan parça **`bitirim_inventory`'ye item
olarak** düşer.

İki tasarım hedefi:

1. **Tam katalog** — kıyafet listesi elle yazılmaz, oyunun kendi verisi çalışma
   anında taranır.
2. **Bozuk kombinasyon yok** — ten taşması / şeffaf mesh üreten kol-üst
   eşleşmeleri katmanlı savunmayla engellenir, kol oyuncuya hiç gösterilmez.

## Dokümanlar

| Dosya | İçerik |
|---|---|
| [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) | **Ten görünmesi / şeffaf mesh çözümü** — katmanlı savunma, doğrulanmış veriler |
| [docs/DESIGN.md](docs/DESIGN.md) | Mimari, katmanlar, veri akışı, envanter entegrasyonu |
| [docs/UI-SPEC.md](docs/UI-SPEC.md) | NUI ekranları, kamera çerçeveleme, fiyatlar |
| [docs/CATALOG.md](docs/CATALOG.md) | Katalog tarama ve thumbnail üretim hattı |

## Doğrulanmış veri (kurtarıldı)

| Dosya | Ne | Kaynak |
|---|---|---|
| [data/compatibility_rules.sql](data/compatibility_rules.sql) | 2613 satır elle doğrulanmış uyumluluk (317 verified / 2296 rejected) | Sunucu DB'si, 2026-09-01 |
| [data/arms_blacklist.lua](data/arms_blacklist.lua) | 11 üst giysinin hepsine karşı reddedilen 64 erkek kol drawable'ı | Canlı test 2026-08-24 |
| [config/coords.lua](config/coords.lua) | Elle ölçülmüş mağaza NPC + önizleme koordinatları | VPS'teki çalışan sürüm |

## Durum

Yeniden inşa aşaması. Bu repo 2026-09-01'de **boş** bulundu (GitHub'da hiç
commit yoktu). Yukarıdaki veriler sunucudan geri alındı; bir daha tek kopyaya
bağlı kalmasınlar diye repoya işlendi.

Çalışan eski sürüm hâlâ VPS'te:
`/opt/fivem/artifacts/txData/Qbox_57FBFD.base/resources/[bitirim]/bitirim_clothing/`

### Bekleyen

- Kalan 48 boşluk parçasının `/kiyafetbosluk` ile gözden geçirilmesi
- Kadın `DefaultArms` ve kadın kol blacklist'i hiç ölçülmedi
- Thumbnail üretimi — çalışıyor. İlk tur (221 şapka) üretildi; kamera
  çerçevelemesi ölçülüp düzeltildikten sonra `yenile` ile tekrarlanmalı
- Kamera çerçeveleme değerlerinin oyunda ölçülmesi (`/kiyafetkamera`)

## Komutlar

| Komut | Ne yapar |
|---|---|
| `/kiyafetkapsam` | Her üst giysinin kolunun **hangi katmandan** çözüldüğünü sayar (oyun / DB / varsayılan). |
| `/kiyafetsay` | Katalog taramasının kategori başına kaç parça bulduğunu yazar. |
| `/kiyafetprob` | Hangi native zincirinin gerçekten veri döndürdüğünü **ölçer**. Katman 1 sıfır çektikten sonra eklendi. |
| `/kiyafetbosluk` | Kol verisi olmayan üstleri tek tek giyip gözden geçirir; bozuk olanı katalogdan çıkarır. |
| `/kiyafetgizli` | Gizlenen parçaları listeler. |
| `/kiyafetcek [kategori] [başlangıç]` | Grid için thumbnail PNG'lerini toplu üretir. Kategori verilmezse hepsi. |
| `/kiyafetcek ... yenile` | Var olan PNG'leri de yeniden çeker (çerçeveleme değişince gerekir). |
| `/kiyafetcekdur` | Üretimi durdurur. |
| `/kiyafetnokta` | Bulunduğun noktayı `Config.CaptureCoords` formatında yazar. |
| `/kiyafetkamera <head\|torso\|legs\|feet> <z> <mesafe> [pitch]` | Önizleme kamerasını canlı ayarlar. Beğenilen değerler `client/preview.lua` içine geçirilir. |

İlk ikisi `bitirim_clothing.dev` ACE yetkisi ister. Yetki **server'da** sorulur —
`IsPlayerAceAllowed` client'ta yoktur.

```
add_ace group.admin bitirim_clothing.dev allow
```

Bu satır `server.cfg`'ye eklenirse **çalışan sürece otomatik yüklenmez**;
txAdmin live console'dan canlı `add_ace ...` çalıştır veya tam restart yap.

## Kurulum

1. Uyumluluk tablosunu içeri aktar (zaten sunucuda varsa atla):
   `mysql -ufivem fivem < data/compatibility_rules.sql`
2. Kaynağı `resources/[bitirim]/bitirim_clothing/` altına koy.
3. ACE yetkisini ver (yukarıdaki satır).
4. `refresh` sonra `restart bitirim_clothing` — **bu sıra zorunlu**, tek başına
   restart eski paketlenmiş cache'i kullanabiliyor.

### Kamera çerçevelemesi ölçüldü (2026-09-01)

İlk thumbnail turundan bir PNG piksel piksel ölçüldü: kafa karenin **%24.3**'ünü
kaplıyordu (hedef ~%55) ve dikey merkezi %49.3'teydi. İki sonuç:

- `z = 0.68` kafayı tam ortalıyor → `GetEntityCoords(ped)` bu ped için **ayak
  değil, pelvis hizası** döndürüyor. Eski `legs`/`feet` değerleri "taban = ayak"
  varsayımıyla yazılmıştı; `feet = taban+0.02` aslında kalça hizasıydı, yani
  **ayakkabı kareye hiç girmiyordu**. Değerler pelvis ankoruna göre yenilendi.
- Kare 2.25× fazla genişti. Mesafeyi kısaltmak yerine FOV daraltılıyor
  (`zoom` alanı) — 0.38 m mesafede perspektif bozulurdu.

`zoom` FOV'a çevrilirken oyunun varsayılan FOV'u `GetCamFov` ile **çalışırken
okunuyor**, sabit varsayılmıyor.

### Tile'da yatay ortalama (ölçüldü, yeniden çekim gerekmedi)

Üretilen karelerde ped yatayda ortada değil — üstelik çerçevelemeye göre farklı
yerde. 1390 karenin üzerinden ölçüldü:

| çerçeveleme | pedin karedeki yeri | kaynak |
|---|---|---|
| head / torso | %42.8 | kırmızı fedora, yeşil bere, beyaz takım — üçü de aynı |
| feet | %56.6 | shoes_10 / _40 / _70 — üçü de aynı |
| legs | ölçülemedi | koyu pantolon testi arka plana karıştı; head/torso değeri kullanılıyor |

Düzeltme NUI tarafında yapıldı, yani **1390 kare yeniden çekilmeden** düzeldi.
`object-position` kullanılmadı: thumb kutusunun en/boyu sabit değil (ölçüldü:
69x55, pencere genişliğine göre değişiyor) ve o yüzdenin anlamı kutu oranına
bağlı. Bunun yerine kaydırma **görüntünün kendi genişliğinin** yüzdesi olarak
veriliyor (`--nudge`), kutu oranı ne olursa olsun aynı sonucu verir.

Tarayıcıda doğrulandı: pedin karedeki noktası kutunun tam %50.0'ında.

### Çekim sırasında sahne kilitli

Bir tur, çekim sürerken `/kiyafetkamera kapat` yazıldığı için bozuldu: kamera
ölünce `place()` sessizce erken dönüyordu, kalan **1200+ kare normal oyun
kamerasıyla ve karakter sokakta yürürken** çekildi. İş yine de
"TAMAMLANDI — 1390 yazıldı" dedi; tek satır hata yoktu.

Artık sahne **her parçada** doğrulanıyor (`ensureStage`): karakter doğru
noktada mı, donuk mu, kamera açık mı — bozulmuşsa toparlanıyor. Ayrıca
karakter çekim boyunca donduruluyor ve `/kiyafetkamera` iş bitene kadar
reddediyor.

Thumbnail üretimi için `/kiyafetcek` (bkz. Komutlar). Dosya yoksa NUI tile'da drawable
numarasını gösterir, kırılmaz.
