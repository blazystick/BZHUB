<!-- BZHUB README -->

<div align="center">

<img src="assets/bzhub-banner.svg" alt="BZHUB banner" width="100%">

<br>

[![Repository](https://img.shields.io/badge/GitHub-BZHUB-181717?style=for-the-badge&logo=github)](https://github.com/blazystick/BZHUB)
[![Language](https://img.shields.io/badge/Language-Lua-2C2D72?style=for-the-badge&logo=lua)](https://www.lua.org/)
[![Platform](https://img.shields.io/badge/Platform-Roblox-168BFF?style=for-the-badge&logo=roblox&logoColor=white)](https://www.roblox.com/)

**Roblox oyunları için modüler GUI ve oyuna özel otomasyon projesi.**

[Özellikler](#-özellikler) · [Desteklenen Oyunlar](#-desteklenen-oyunlar) · [Kurulum](#-kurulum) · [Proje Yapısı](#-proje-yapısı)

</div>

---

## ✨ Özellikler

<table>
<tr>
<td width="50%">

### 🎨 Modern Arayüz
Koyu tasarım, mavi neon vurgular, animasyonlar ve sürüklenebilir pencere.

</td>
<td width="50%">

### 🕹️ Oyun Algılama
Açık olan oyunun PlaceId değerini kontrol eder ve destek durumunu gösterir.

</td>
</tr>
<tr>
<td width="50%">

### 🌈 Görünüm Seçenekleri
Blue, Purple, Green ve Red temaları.

</td>
<td width="50%">

### 🌍 Çoklu Dil
English, Türkçe ve Русский arayüz seçenekleri.

</td>
</tr>
<tr>
<td width="50%">

### 🧩 Modüler Sistem
Oyunlara özel kodlar ayrı `SupportedGames` dosyalarında tutulur.

</td>
<td width="50%">

### 🪟 Pencere Kontrolleri
Küçültme, yeniden boyutlandırma ve arayüzü kapatma kontrolleri.

</td>
</tr>
</table>

## 🎮 Desteklenen Oyunlar

| Oyun | PlaceId | Durum |
|:--|:--:|:--:|
| Throw Food for Animals | `120219252362013` | 🟢 Destekleniyor |

> BZHUB, yalnızca ana scriptte desteklenen olarak tanımlanan oyunlarda oyuna özel modülleri yükler. Destek listesi zamanla değişebilir.

## 🧭 Arayüz Bölümleri

| Bölüm | Açıklama |
|:--|:--|
| **Home** | Karşılama ve genel durum ekranı |
| **Information** | Arayüz kullanım bilgileri (desteklenen oyunlarda) |
| **Settings** | Tema ve dil seçenekleri |
| **Automation** | Oyun modülünün sunduğu otomasyon kontrolleri |

## 📁 Proje Yapısı

```text
BZHUB/
├── assets/
│   └── bzhub-banner.svg
├── SupportedGames/
│   ├── 120219252362013.lua
│   ├── 120219252362013_2.lua
│   ├── 91704854174760.lua
│   └── 91704854174760_2.lua
└── main.lua
```

- **`main.lua`** — Ana arayüz, oyun algılama ve ortak sistemler.
- **`SupportedGames/`** — Oyunlara özel Lua modülleri.
- **`assets/`** — README ve proje görselleri.

## 🚀 Kurulum

1. [BZHUB deposunu](https://github.com/blazystick/BZHUB) aç.
2. **Code → Download ZIP** seçeneğiyle dosyaları indir.
3. Roblox'ta desteklenen oyuna katıl.
4. `main.lua` dosyasını kullandığın Roblox Lua executor ortamında çalıştır.
5. Arayüzdeki oyun durumunu kontrol et.

## 🛠️ Geliştirme

Yeni bir oyun desteği eklerken oyuna özel kodu mümkün olduğunca `SupportedGames/<PlaceId>.lua` dosyasında tut. Ortak arayüz ve sistemleri, gerekli olmadıkça `main.lua` içinde değiştirme.

## ⚠️ Uyarı

- BZHUB, Roblox tarafından geliştirilmiş veya resmî olarak onaylanmış değildir.
- Üçüncü taraf script ve executor kullanımı hesabın veya cihazın için risk oluşturabilir.
- Yalnızca kaynağına güvendiğin kodları çalıştır.
- Roblox oyun güncellemeleri, oyun modüllerinin çalışmasını etkileyebilir.

---

<div align="center">

**BZHUB** · Made by **blazystick**

<sub>Built for a cleaner and more organized Roblox GUI experience.</sub>

</div>
