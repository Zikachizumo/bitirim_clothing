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

## Sıradaki iş: katman 1'in kapsamını ÖLÇ

Önceki yaklaşım her üst giysiyi ~214 kola karşı **elle, gözle** test etmekti;
2026-08-24'te haklı olarak bırakıldı (11 üst giysi için 2613 satır sürdü).

Onu tekrarlamaya gerek yok. Katman 1 oyunun kendi verisi olduğu için
**insansız** ölçülebilir: her Top drawable için `GetNumForcedComponents`
çağır, kaçının kol cevabı verdiğini say.

```
/kiyafetkapsam        → "N top tarandı, M tanesi için oyun kol veriyor (%X)"
```

Bu tek komut, elle taramaya devam etmeye değip değmeyeceğini söyler.
Katman 1 yüksek kapsam veriyorsa manuel tarama tamamen gereksiz; düşükse
sadece **açıkta kalan** üst giysiler taranır — hepsi değil.

Çıkan sayı buraya yazılacak. **Şu an ölçülmedi, tahmin de edilmeyecek.**

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
