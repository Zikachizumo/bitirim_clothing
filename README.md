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

- Katman 1 (`GetNumForcedComponents`) kapsam ölçümü — bkz. COMPATIBILITY.md
- Kadın `DefaultArms` ve kadın kol blacklist'i hiç ölçülmedi
- Katalog tarama + thumbnail üretimi
- NUI
