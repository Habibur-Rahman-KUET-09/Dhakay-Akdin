# ঢাকার একদিন

একটা মোবাইল গেম। খেলোয়াড় প্রতিদিন ঢাকার একজন ভিন্ন সাধারণ মানুষ হয়ে ৩–৫ মিনিটের একটা "দিন" কাটায়: রিকশাওয়ালা, বাস কন্ডাক্টর, চা-দোকানি… প্রতিটা চরিত্রের নিজস্ব মিনি-গেম আছে, কিন্তু সবাই একই মহল্লা আর একই গল্পের অংশ।

| ফাইল | কী |
|---|---|
| `docs/GDD_v1.pdf` | মূল Game Design Document |
| `docs/DETAILED_DESIGN.md` | বিস্তারিত ডিজাইন: চরিত্রের নিয়ম ও সংখ্যা, স্ক্রিন, অর্থনীতি, কোডের গঠন, সাপ্তাহিক পরিকল্পনা |

স্ট্যাক: Flutter + Flame, Android প্রথমে।

| ফোল্ডার | কী |
|---|---|
| `app/` | Flutter + Flame গেম (`lib/economy`, `lib/ui`, `lib/characters`…) |
| `app/assets/content/balance.json` | গেমের সব সংখ্যা: দাম, গতি, সময় (কোডে কোনো সংখ্যা নেই) |
| `tool/validate_content.py` | লেখা আর সংখ্যা যাচাই, বাংলা ফন্ট সব অক্ষর আঁকতে পারে কি না সহ |
| `app/assets/content/maps/` | রিকশার ম্যাপ, আসল রাস্তা থেকে বানানো |
| `tool/fetch_osm.py`, `.github/workflows/osm.yml` | OpenStreetMap থেকে এলাকার আসল রাস্তা আর জায়গা নামানো (`tool/osm/`) |
| `tool/build_map.py` | সেই রাস্তা থেকে খেলার ম্যাপ বানানো: `python3 tool/build_map.py mirpur` |
| `.github/workflows/app.yml` | প্রতিটা push-এ analyze, test, APK আর GitHub pre-release |

চালানো:

```bash
cd app && flutter pub get && flutter test && flutter run
python3 tool/validate_content.py   # pip install fonttools
```

ম্যাপের তথ্য: © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, ODbL 1.0। গেমের পর্দাতেও লেখা থাকে।
