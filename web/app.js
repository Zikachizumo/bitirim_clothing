/*
    bitirim_clothing NUI

    Lua ile sozlesme:
      gelen : { action: 'open', data: { categories, catalog, gender, currency } }
              { action: 'close' }
      giden : selectCategory { category }
              selectItem     { category, drawable, texture }
              rotate         { delta }
              addToCart      { category, drawable, texture }
              removeFromCart { index }
              checkout       {}
              close          {}

    Tarayicida (FiveM disinda) acilirsa DEBUG verisiyle kendini doldurur --
    tasarim FiveM'e gitmeden gorsel olarak denetlenebilsin diye.
*/

(function () {
    'use strict';

    const IN_GAME = typeof window.GetParentResourceName === 'function';
    const RES = IN_GAME ? window.GetParentResourceName() : 'bitirim_clothing';

    // ------------------------------------------------------------- ikonlar
    const ICONS = {
        hat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M4 16c0-1 1.6-1.7 3.2-2M20 16c0-1-1.6-1.7-3.2-2"/><path d="M7.2 14 8.4 6.6C8.6 5.6 9.5 5 10.5 5h3c1 0 1.9.6 2.1 1.6L16.8 14"/><ellipse cx="12" cy="16.2" rx="8.6" ry="2.6"/></svg>',
        jacket: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M9 3 4 6l1.4 5L4 21h16l-1.4-10L20 6l-5-3"/><path d="M9 3c0 1.7 1.3 3 3 3s3-1.3 3-3"/><path d="M12 6v15"/></svg>',
        tshirt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M9 3 4 6l2 4 1-.7V21h10V9.3l1 .7 2-4-5-3"/><path d="M9 3c0 1.7 1.3 3 3 3s3-1.3 3-3"/></svg>',
        pants: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M6 3h12l-.7 18h-4L12 11l-1.3 10h-4z"/><path d="M6 7h12"/></svg>',
        shoes: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M2 17v-5h4l3.2 2.2c1.6 1.1 3.5 1.7 5.4 1.8l4 .2c1.9.1 3.4 1.7 3.4 3.6v.2H2z"/><path d="M6 12l1.5 2M9 13l1.5 2"/></svg>',
        glasses: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="6.5" cy="13" r="3.5"/><circle cx="17.5" cy="13" r="3.5"/><path d="M10 13c0-1 .9-1.6 2-1.6s2 .6 2 1.6M3 11l1.6-2.6M21 11l-1.6-2.6"/></svg>',
    };

    // --------------------------------------------------------------- durum
    const S = {
        categories: [],
        catalog: {},
        currency: '$',
        gender: 'male',
        category: null,        // aktif kategori nesnesi
        entry: null,           // secili parca (adi buradan okunuyor)
        drawable: null,
        texture: 0,
        qty: 1,
        cart: [],
    };

    const $ = (id) => document.getElementById(id);

    function post(name, body) {
        if (!IN_GAME) return Promise.resolve({});
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then((r) => r.json()).catch(() => ({}));
    }

    function toast(msg, kind) {
        const t = $('toast');
        t.textContent = msg;
        t.className = 'toast ' + (kind || '');
        clearTimeout(toast._t);
        toast._t = setTimeout(() => t.classList.add('hidden'), 2600);
    }

    // ------------------------------------------------------------ ekranlar
    function showRoot() {
        S.category = null;
        S.entry = null;
        S.drawable = null;
        $('view-root').classList.remove('hidden');
        $('view-category').classList.add('hidden');
        $('item-card').classList.add('hidden');
    }

    function renderCategories() {
        const nav = $('category-list');
        nav.innerHTML = '';
        S.categories.forEach((c) => {
            const row = document.createElement('div');
            row.className = 'cat-row';
            row.innerHTML = `<span>${c.label}</span><span class="ico">${ICONS[c.icon] || ''}</span>`;
            row.addEventListener('click', () => openCategory(c));
            nav.appendChild(row);
        });
    }

    function openCategory(category) {
        S.category = category;
        S.entry = null;
        S.drawable = null;
        S.texture = 0;
        S.qty = 1;

        $('view-root').classList.add('hidden');
        $('view-category').classList.remove('hidden');
        $('cat-title').textContent = category.label;
        $('cat-icon').innerHTML = ICONS[category.icon] || '';
        $('item-card').classList.add('hidden');

        renderGrid();
        post('selectCategory', { category: category.key });
    }

    function renderGrid() {
        const grid = $('grid');
        grid.innerHTML = '';

        const list = S.catalog[S.category.key] || [];
        if (list.length === 0) {
            const empty = document.createElement('div');
            empty.style.cssText = 'grid-column:1/-1;color:var(--text-faint);font-size:13px;padding:18px 2px;';
            empty.textContent = 'Bu kategoride parca bulunamadi (katalog taramasi bos dondu).';
            grid.appendChild(empty);
            return;
        }

        list.forEach((entry) => {
            const tile = document.createElement('div');
            tile.className = 'tile';
            tile.dataset.drawable = entry.d;

            // Butun gorseller artik model dosyasindan render edilmis, saydam
            // zeminli, KARE parcalar. Eskiden oyun ekranindan alinmis 512x280
            // kareler de vardi ve pedi ortalamak icin kategoriye gore yatay
            // kaydirma (fit-* / .iso) gerekiyordu; onlar kalmadigi icin o
            // mekanizma da kaldirildi.
            // Gorsel eksik kalirsa numara ile fallback.
            const src = `images/${S.category.slot || S.category.key}_${entry.d}.png`;
            //  Parca numarasi (drawable indeksi) her tile'in kosesinde duruyor.
            //  Bir parcayi konusabilmek icin tek gereken sey bu numara:
            //  "outerwear 478" gibi. Numara oyunun kendi indeksi, kategoriye
            //  ozel -- yani ayni numara farkli kategoride baska parcadir.
            tile.innerHTML =
                `<div class="thumb">` +
                    `<img src="${src}" alt="" onerror="this.replaceWith(document.createTextNode('${entry.d}'))">` +
                    `<span class="num">${entry.d}</span>` +
                `</div>` +
                `<div class="cap"><span class="caret">&#9662;</span>${entry.name || S.category.itemLabel || S.category.label}</div>`;

            tile.addEventListener('click', () => selectTile(entry, tile));
            grid.appendChild(tile);
        });
    }

    function selectTile(entry, tile) {
        document.querySelectorAll('.tile.selected').forEach((t) => t.classList.remove('selected'));
        document.querySelectorAll('.swatches').forEach((s) => s.remove());
        tile.classList.add('selected');

        S.entry = entry;
        S.drawable = entry.d;
        S.texture = entry.t && entry.t.length ? entry.t[0] : 0;

        // Renk varyantlari (texture) — tile'in hemen altina serit olarak.
        if (entry.t && entry.t.length > 1) {
            const strip = document.createElement('div');
            strip.className = 'swatches';
            entry.t.forEach((tex) => {
                const b = document.createElement('button');
                b.className = 'swatch' + (tex === S.texture ? ' selected' : '');
                b.textContent = tex;
                b.addEventListener('click', (ev) => {
                    ev.stopPropagation();
                    S.texture = tex;
                    strip.querySelectorAll('.swatch').forEach((x) => x.classList.remove('selected'));
                    b.classList.add('selected');
                    applyPreview();
                });
                strip.appendChild(b);
            });
            tile.parentNode.insertBefore(strip, tile.nextSibling);
        }

        showItemCard();
        applyPreview();
    }

    function applyPreview() {
        post('selectItem', {
            category: S.category.key,
            drawable: S.drawable,
            texture: S.texture,
        }).then((r) => {
            if (r && r.ok === false) toast('Bu parca uygulanamadi.', 'err');
        });
    }

    function showItemCard() {
        S.qty = 1;
        $('qty').textContent = '1';
        $('item-name').textContent =
            (S.entry && S.entry.name) || S.category.itemLabel || S.category.label;
        //  Kategori adi + parca numarasi: bir parcayi tarif etmek icin yeterli
        //  ("outerwear 478"). Tile kosesindeki numarayla ayni sey.
        $('item-crumb-text').textContent =
            'CLOTHING / ' + (S.gender === 'female' ? 'WOMENS' : 'MENS') +
            ' / ' + S.category.key.toUpperCase() + ' ' + S.drawable;
        $('item-price').textContent = S.currency + ' ' + fmt(S.category.price);
        $('item-card').classList.remove('hidden');
    }

    function fmt(n) {
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    }

    // --------------------------------------------------------------- sepet
    function renderCart() {
        const n = S.cart.length;
        $('cart-count').textContent = String(n);
        $('cart-count').classList.toggle('hidden', n === 0);
        $('cart-text').textContent = n === 0
            ? 'THERE ARE NO ITEMS IN THE SHOPPING CART'
            : `SEPETTE ${n} PARCA VAR`;

        const ul = $('cart-list');
        ul.innerHTML = '';
        let total = 0;
        S.cart.forEach((line, i) => {
            total += line.price;
            const li = document.createElement('li');
            li.innerHTML = `<span>${line.label} #${line.drawable}</span>` +
                `<span>${S.currency} ${fmt(line.price)} <button class="rm" data-i="${i}">&times;</button></span>`;
            ul.appendChild(li);
        });
        $('cart-total').textContent = S.currency + ' ' + fmt(total);

        ul.querySelectorAll('.rm').forEach((b) => {
            b.addEventListener('click', () => {
                const i = parseInt(b.dataset.i, 10);
                post('removeFromCart', { index: i + 1 });
                S.cart.splice(i, 1);
                renderCart();
            });
        });
    }

    // ------------------------------------------------------------ olaylar
    function bind() {
        $('back-btn').addEventListener('click', showRoot);

        $('close-btn').addEventListener('click', () => post('close'));

        $('qty-minus').addEventListener('click', () => {
            S.qty = Math.max(1, S.qty - 1);
            $('qty').textContent = String(S.qty);
        });
        $('qty-plus').addEventListener('click', () => {
            S.qty = Math.min(10, S.qty + 1);
            $('qty').textContent = String(S.qty);
        });

        $('add-cart').addEventListener('click', () => {
            if (S.drawable === null) return;
            for (let i = 0; i < S.qty; i++) {
                post('addToCart', {
                    category: S.category.key,
                    drawable: S.drawable,
                    texture: S.texture,
                });
                S.cart.push({
                    label: (S.entry && S.entry.name) || S.category.itemLabel || S.category.label,
                    drawable: S.drawable,
                    price: S.category.price,
                });
            }
            renderCart();
            toast('Sepete eklendi.', 'ok');
        });

        $('cart-btn').addEventListener('click', () => {
            $('cart-panel').classList.toggle('hidden');
        });

        $('checkout-btn').addEventListener('click', () => {
            post('checkout').then((r) => {
                if (r && r.success) {
                    S.cart = [];
                    renderCart();
                    toast('Satin alindi.', 'ok');
                } else {
                    toast((r && r.reason) || 'Satin alma basarisiz.', 'err');
                }
            });
        });

        // ESC
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') post('close');
        });

        // Karakteri fareyle dondur — panelin DISINDA surukleme.
        let dragging = false, lastX = 0;
        document.addEventListener('mousedown', (e) => {
            if (e.target.closest('.panel, .item-card, .cart-area, .cart-panel, .close-btn')) return;
            dragging = true;
            lastX = e.clientX;
        });
        document.addEventListener('mousemove', (e) => {
            if (!dragging) return;
            const dx = e.clientX - lastX;
            lastX = e.clientX;
            if (dx !== 0) post('rotate', { delta: dx * 0.4 });
        });
        document.addEventListener('mouseup', () => { dragging = false; });
    }

    // ---------------------------------------------------------- Lua koprusu
    window.addEventListener('message', (ev) => {
        const msg = ev.data || {};
        if (msg.action === 'open') {
            const d = msg.data || {};
            S.categories = d.categories || [];
            S.catalog = d.catalog || {};
            S.gender = d.gender || 'male';
            S.currency = d.currency || '$';
            S.cart = [];

            // Kategori nesnesine slot/itemLabel de gelsin diye eslestir.
            renderCategories();
            renderCart();
            showRoot();
            $('app').classList.remove('hidden');
        } else if (msg.action === 'close') {
            $('app').classList.add('hidden');
            $('cart-panel').classList.add('hidden');
        }
    });

    bind();

    // --------------------------------------------------- tarayici DEBUG modu
    if (!IN_GAME) {
        const mk = (n) => Array.from({ length: n }, (_, i) => ({
            d: i, t: Array.from({ length: 1 + (i % 4) }, (_, k) => k),
        }));
        window.postMessage({
            action: 'open',
            data: {
                gender: 'male',
                currency: '$',
                categories: [
                    { key: 'headwear',  label: 'HEADWEAR',  icon: 'hat',     price: 600,  camera: 'head',  itemLabel: 'Mens headwear',  slot: 'hat' },
                    { key: 'outerwear', label: 'OUTERWEAR', icon: 'jacket',  price: 1350, camera: 'torso', itemLabel: 'Mens outerwear', slot: 'jacket' },
                    { key: 'tshirts',   label: 'T-SHIRTS',  icon: 'tshirt',  price: 1000, camera: 'torso', itemLabel: 'Mens T-shirt',   slot: 'tshirt' },
                    { key: 'pants',     label: 'PANTS',     icon: 'pants',   price: 600,  camera: 'legs',  itemLabel: 'Mens pants',     slot: 'pants' },
                    { key: 'shoes',     label: 'SHOES',     icon: 'shoes',   price: 850,  camera: 'feet',  itemLabel: 'Mens Shoes',     slot: 'shoes' },
                    { key: 'glasses',   label: 'GLASSES',   icon: 'glasses', price: 1000, camera: 'head',  itemLabel: 'Mens glasses',   slot: 'glasses' },
                ],
                catalog: {
                    headwear: mk(38), outerwear: mk(64), tshirts: mk(52),
                    pants: mk(48), shoes: mk(44), glasses: mk(30),
                },
            },
        }, '*');
    }
})();
