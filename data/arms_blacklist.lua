--[[
    GLOBAL ARMS (component 3) BLACKLIST — ERKEK

    Bu 64 drawable, compatibility taramasinda test edilen 11 farkli Topwear
    kaynagina (11/14 .. 11/24) karsi ISTISNASIZ (0/11) REJECTED cikti. Yani
    sorun Top ile kombinasyonda degil, Arms drawable'inin KENDISINDE.
    Bu yuzden hicbir yerde gosterilmez, hicbir Top icin secilmez.

    Canli oyunda dogrulandi (2026-08-24): Hands 2 ve 3 picker'da gizlendi,
    Hands 168 (liste disi) gorunur kaldi.

    KADIN BILEREK BOS: hic test edilmedi. Tahminle doldurulmaz -- kadin
    ped'inde ayni indeks bambaska bir parcadir.

    KRITIK AYRIM: Bir drawable TEK BIR Top'ta bile VERIFIED cikmissa buraya
    GIRMEZ (or. Arms 168: 11/24'te REJECTED ama 11/23'te VERIFIED). O tur
    vakalar Top-ozel compatibility DB'sinin isidir, global blacklist'in degil.
]]

return {
    male = {
        2, 3, 7, 8, 9, 10, 11, 13, 21, 25, 26, 32, 36, 37, 43, 47, 48, 54,
        58, 59, 65, 69, 70, 76, 80, 81, 87, 91, 92, 101, 105, 106, 113, 122,
        123, 124, 125, 126, 127, 128, 140, 144, 145, 149, 153, 157, 158, 162,
        173, 177, 178, 182, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193,
        194, 196,
    },
    female = {},
}
