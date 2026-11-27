# BZHUB

BZHUB, Roblox oyunları için hazırlanmış, oyunlara özel otomasyon özellikleri sunan bir Lua GUI scriptidir.

Arayüz; sade, modern ve koyu bir tasarıma sahiptir. Mavi neon vurgular, animasyonlar ve kişiselleştirilebilir görünüm seçenekleri kullanır.

## Özellikler

- **Modern arayüz:** Koyu tema, mavi vurgular, yumuşak animasyonlar ve sürüklenebilir pencere.
- **Pencere kontrolleri:** Küçültme, pencere boyutunu değiştirme ve arayüzü kapatma.
- **Çoklu dil:** English, Türkçe ve Русский.
- **Temalar:** Blue, Purple, Green ve Red.
- **Oyun algılama:** Açık olan oyunun PlaceId değerini kontrol eder ve destek durumunu gösterir.
- **Oyun modülleri:** Oyuna özel özellikler `SupportedGames/<PlaceId>.lua` dosyalarında tutulur.

## Desteklenen oyunlar

| Oyun | PlaceId |
|---|---:|
| Throw Food for Animals | `120219252362013` |

> BZHUB yalnızca destek listesinde bulunan oyunlarda oyun-özel özellikleri yükler. Desteklenmeyen oyunlarda arayüz desteklenmediğini belirtir.

## Arayüz

- **Home:** Karşılama ve genel durum ekranı.
- **Information:** Desteklenen oyunlarda arayüz kullanım bilgileri.
- **Settings:** Tema ve dil gibi arayüz seçenekleri.
- **Automation:** Desteklenen oyuna ait otomasyon kontrolleri.

## Proje yapısı

```text
BZHUB/
├── main.lua
└── SupportedGames/
    ├── 120219252362013.lua
    └── ...
```

- `main.lua`: Ana arayüzü, oyun algılamayı ve ortak sistemleri yönetir.
- `SupportedGames/`: Her desteklenen oyun için ayrı Lua modüllerini içerir.

## Kurulum ve kullanım

1. Depoyu ZIP olarak indir veya projeyi bilgisayarına klonla.
2. Roblox'ta desteklenen oyuna katıl.
3. `main.lua` dosyasını kullandığın Roblox Lua executor ortamında çalıştır.
4. BZHUB arayüzündeki oyun durumunu kontrol et ve mevcut seçenekleri kullan.

## Önemli notlar

- BZHUB, Roblox tarafından geliştirilmiş veya resmî olarak onaylanmış bir ürün değildir.
- Script kullanımı Roblox'un kullanım şartlarıyla çelişebilir ve hesabın için risk oluşturabilir.
- Yalnızca güvendiğin kodları çalıştır. Executor kullanımı ve üçüncü taraf scriptler kendi güvenlik risklerini taşır.
- Oyun güncellemeleri, oyun modüllerinin çalışmasını bozabilir.

## Geliştirme

Yeni oyun desteği eklerken mümkün olduğunca oyuna özel kodu `SupportedGames/<PlaceId>.lua` içinde tut. Ana arayüz ve ortak sistemleri, gerekli olmadıkça `main.lua` içinde değiştirme.
