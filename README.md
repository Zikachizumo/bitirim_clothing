# bitirim_clothing

Bitirim RP için GrandRP tarzı kıyafet mağazası (FiveM / Qbox).
NPC'ye `E` ile girilir, oyuncu 3D olarak kendini görerek dener, sepete ekler,
satın alınan parça **`bitirim_inventory`'ye item olarak** düşer.

Katalog **elle yazılmaz**: oyunun kendi kıyafet verisi çalışma anında GTA
native'leriyle taranır, böylece sunucudaki FiveM sürümü ne sunuyorsa mağazada o
görünür.

## Dokümanlar

| Dosya | İçerik |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Mimari, katmanlar, veri akışı, envanter entegrasyonu |
| [docs/UI-SPEC.md](docs/UI-SPEC.md) | NUI ekranları, kamera çerçeveleme, fiyatlar |
| [docs/CATALOG.md](docs/CATALOG.md) | Katalog tarama ve thumbnail üretim hattı |

## Durum

**Yeniden inşa aşaması.** Bu repo 2026-09-01'de boş bulundu (GitHub'da hiç
commit yoktu). Çalışan eski sürüm VPS'te duruyor:

```
/opt/fivem/artifacts/txData/Qbox_57FBFD.base/resources/[bitirim]/bitirim_clothing/
```

Eski sürümdeki **elle ölçülmüş** `config/coords.lua` (mağaza NPC konumu +
önizleme ışınlanma noktası + interior ankor override) oradan geri alınmalı —
yeniden ölçmek pahalı.
