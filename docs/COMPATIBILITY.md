# Ten görünmesi / şeffaf mesh — katmanlı savunma

Sorun: GTA freemode ped'inde bir üst giysi (component 11) giyildiğinde,
uyumsuz bir kol (component 3) omuzda **ten taşmasına**, kaybolan yüzeye veya
**şeffaf mesh'e** yol açar. Aynı sorun daha hafif biçimde alt katmanlarda
(component 8) da görülür.

Bu dokümandaki her sayı ya canlı oyunda doğrulandı ya da sunucudaki DB'den
okundu. Tahmin yok.

## Temel karar: Kol oyuncuya HİÇ gösterilmez

Mağazadaki 6 kategoride **ARMS/HANDS yok** — referans görsellerdeki kategori
listesiyle de birebir uyuşuyor. Kol, oyuncunun seçebileceği bir şey değil;
üst giysiye göre **otomatik** belirlenir. Oyuncuya seçtirilirse hangi savunma
katmanı konursa konsun bozuk kombinasyon üretilebilir.

## Katmanlar (sırayla denenir, ilk cevap veren kazanır)

### Katman 0 — Katalog süzgeci
`IsPedComponentVariationValid(ped, comp, drawable, texture)` **false** dönen
kombinasyon katalog taramasında hiç listeye girmez. Geçersiz drawable
uygulanırsa ped görünümü direkt bozulur.

### Katman 1 — GTA'nın kendi zorunlu-bileşen verisi ⭐

Oyun, her üst giysi için hangi kolun zorunlu olduğunu **kendi verisinde
zaten tutuyor**. Bu veri iki native ile okunuyor ve **bitirim_inventory'de
şu anda üretimde çalışıyor** (`modules/bitirim/equipment_client.lua:71-87`):

```lua
GetNumForcedComponents(model, 11, topDrawable, 0)      --> adet
GetForcedComponent(model, 11, topDrawable, i)          --> nameHash, enumValue, componentType
                                                       --  componentType == 3 ise enumValue = kol drawable'i
```

Üretimdeki kod ikisini de `pcall` ve varlık kontrolüyle sarıyor — burada da
aynısı yapılır.

**Bu katman neden belirleyici:** taranmış 11 üst giysiyle sınırlı değil,
**bütün** üst giysiler için çalışır ve yeni DLC geldiğinde kendini günceller.

### Katman 2 — Elle doğrulanmış compatibility DB (2613 satır)

Katman 1 cevap vermezse devreye girer. Sunucudaki
`bitirim_clothing_compatibility_rules` tablosundan (2026-09-01'de çekildi,
[data/compatibility_rules.sql](../data/compatibility_rules.sql)):

| kaynak → hedef | verified | rejected |
|---|---|---|
| Top(11) → Arms(3) | 317 | 2090 |
| Top(11) → Undershirt(8) | 0 | 206 |
| **toplam** | **317** | **2296** |

Taranan Top drawable'ları ve kaç kolun geçtiği:

| Top | verified | rejected |
|---|---|---|
| 14 | 3 | 209 |
| 15 | 12 | 200 |
| 16 | 23 | 190 |
| 17 | 11 | 202 |
| 18 | 21 | 192 |
| 19 | 11 | 202 |
| 20 | 12 | 201 |
| 21 | 46 | 167 |
| 22 | 22 | 190 |
| 23 | 81 | 132 |
| 24 | 75 | 138 |
| 25 | 0 | 67 *(tur yarıda bırakıldı)* |

Kurallar:
- **Eşleşme strict equality** — component+drawable+texture+collection birebir.
  Wildcard yok: bir texture için doğrulanan kombinasyon diğer texture'lara
  asla genellenmez.
- **Çakışmada REJECTED kazanır.** Aynı çift için hem verified hem rejected
  varsa parça uygulanmaz.
- `Top → Arms` **required**: doğrulanmış değer yoksa bir sonraki katmana düşer.
- `Top → Undershirt` **optional**: 206 rejected / 0 verified çıktığı için
  zorunlu tutmak sistemi kullanılamaz hale getirirdi. Doğrulanmış değer yoksa
  ped'in mevcut component 8 değerine **dokunulmaz** — uydurma fallback yok.

### Katman 3 — Global kol blacklist (64 drawable)

[data/arms_blacklist.lua](../data/arms_blacklist.lua). Test edilen 11 üst
giysinin **hepsine** karşı reddedilen 64 erkek kol drawable'ı; sorun
kombinasyonda değil kolun kendisinde. Hiçbir yerde gösterilmez, hiçbir üst
için seçilmez.

Bu liste sunucuda `illenium-appearance/shared/blacklist.lua` →
`Config.Blacklist.male.components.upperBody` içinde **canlı ve çalışır
durumda** (2026-09-01'de doğrulandı). Yani appearance menüsünde bu kollar
zaten gizli.

**Kadın listesi bilerek boş** — hiç test edilmedi, tahminle doldurulmaz.

### Katman 4 — Son çare varsayılan

Hiçbir katman cevap vermezse `Config.DefaultArms`:
`male = 135` (oyunda ölçüldü, **eldivenli** bir parça),
`female = -1` (**ölçülmedi** → kola hiç dokunma).

## Katman 1 hata ayıklaması (2026-09-01) — model ≠ apparel hash

İlk ölçüm **%0 kapsam** verdi: 544 üst giysinin hiçbirinde
`GetNumForcedComponents` cevap vermedi. Sebep verinin yokluğu değildi —
**native'e yanlış anahtar veriliyordu.**

`/kiyafetprob` ile ölçülen kanıt:

```
GetNumForcedComponents(model)         -> 0     ← eski çağrı
GetNumForcedComponents(apparelHash)   -> 2     ← doğrusu
GetForcedComponent(apparelHash, 0)    -> 1849449579, 5, 3
                                          nameHash, enumValue=5, componentType=3 (ARMS)
```

Native, ped'in **model hash'ini değil**, `GetHashNameForComponent`'ten gelen
**apparel component hash'ini** bekliyor. Model verilince hata vermiyor, sessizce
`0` dönüyor — bu yüzden fark edilmesi zordu.

### Doğru zincir

```lua
local hash  = GetHashNameForComponent(ped, 11, drawable, texture)
local count = GetNumForcedComponents(hash)
for i = 0, count - 1 do
    local nameHash, enumValue, componentType = GetForcedComponent(hash, i)
    -- componentType == 3 ise enumValue = zorunlu KOL drawable'i
end
```

Hash **texture'a da bağlı**: aynı drawable'ın farklı renginin zorunlu kolu
farklı olabilir. Layer 1 bu yüzden texture'ı da geçiriyor.

### Karıştırılmaması gereken native

`GetVariantComponent(hash, i)` de üç değer döndürür ama **başka veridir** —
ölçümde `componentType` 8/9/11 (undershirt / yelek / üst) çıktı, kol vermez.

### Aynı hata bitirim_inventory'de de var

`bitirim_inventory/modules/bitirim/equipment_client.lua:71` aynı çağrıyı model
hash'iyle yapıyor. Yani envanterin "üst giyilince doğru kolu otomatik uygula"
özelliği de hiç çalışmamış olmalı; `defaultArms`'a düşme davranışı bunu
maskeliyor.

### Düzeltme sonrası kapsam (ölçüldü)

`/kiyafetkapsam`, `mp_m_freemode_01`, 544 üst giysi:

| | önce | sonra |
|---|---|---|
| katman 1 (oyun) | 0 (%0.0) | **428 (%78.7)** |
| katman 2 (DB) | 11 (%2.0) | 5 (%0.9) |
| katman 4 (varsayılan) | 533 (%98.0) | 111 (%20.4) |
| **gerçek kapsam** | **%2.0** | **%79.6** |

DB payının 11'den 5'e düşmesi beklenen davranış: katman 1 artık o parçaların
çoğunda önce cevap veriyor.

### Kalan 111'in sebep kırılımı (ölçüldü)

| sebep | adet | anlamı |
|---|---|---|
| `blacklisted` | **47** | oyun kol cevabı verdi, blacklist reddetti |
| `no_forced` | 48 | hash var ama hiç zorunlu bileşen kaydı yok — gerçek boşluk |
| `no_hash` | 14 | mağaza kataloğunda yok (taban parçalar, drawable 0–13) — zararsız |
| `no_arms` | 2 | oyun kolu serbest bırakıyor — zararsız |

### Karar: blacklist katman 1'i süzmüyor (2026-09-01)

`Config.BlacklistFiltersGameData = false`. Gerekçe ölçüme dayanıyor: 47 üst
giyside oyun **zaten doğru kolu söylüyordu**, blacklist reddediyordu.

Blacklist yalnızca **11 üst giysiye** (14–24) karşı test edilerek kurulmuştu ve
o testlerde kollar, **kendilerini zorunlu kılmayan** üstlerle eşleştirilmişti —
uyumsuz bir kolun bozuk görünmesi zaten beklenen sonuçtur. "Kol X, 14–24 ile
kötü" ifadesi "Kol X, onu zorunlu kılan üstle kötü" anlamına gelmez. Rockstar'ın
parça-bazlı verisi, 11 örnekten yapılan genellemeden daha spesifik bir kanıttır.

**Güvenlik ağı duruyor:** DB'nin o (üst, kol) çiftine **özel** `rejected` kaydı
katman 1'in cevabını yine veto eder (`resolveArms` → `isRejected`). Körü körüne
güven yok; yalnızca **küt** global blacklist katman 1'e uygulanmıyor. Blacklist
katman 2 ve 4'te çalışmaya devam ediyor.

Beklenen kapsam ~%88.3 — **doğrulanacak.**

### Açık kalan: 48 `no_forced`

Bunlarda oyunun hiç zorunlu bileşen kaydı yok. Ucuz bir ihtimal ölçülüyor:
hash texture'a bağlı olduğu için texture 0'da veri olmayan bir parçanın başka
bir renginde veri olabilir. `/kiyafetkapsam` bunu ayrıca raporluyor
(`Compat.forcedArmsAnyTexture`). Sayı yüksek çıkarsa katman 1'e texture
taraması eklenir — **önce ölçülür, sonra yazılır.**

## Kurulum / deploy

```
refresh
restart bitirim_clothing
```

Bu sıra zorunlu: FXServer `cache/files/<resource>/` altında paketlenmiş eski
sürümü tutabiliyor, tek başına `restart` onu yenilemeyebiliyor.

DB'ye doğrudan SQL yazıldıysa (`compatibility_rules.sql` geri yüklemesi gibi)
cache otomatik senkron **olmaz** — kurallar bellekte resource start'ta bir kez
yükleniyor. Ham SQL sonrası restart şart.
