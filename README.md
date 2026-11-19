# Roguesort (tytuł roboczy)

Roguelite łamigłówkowy o sortowaniu, wychodzący z *Bubble Sort Quest*.
Porządkujesz liczby ruchami prawdziwych algorytmów, a przedmioty łączą się
w synergie jak w Isaacu i mnożą wynik jak w Balatro.

Dokument projektowy: https://claude.ai/artifact/5ETaojyCo7PVF7KUTtAXea

Silnik: **Godot 4.7**, GDScript.

## Jak zagrać

Otwórz folder w Godocie i wciśnij F5, albo z wiersza poleceń:

```bash
godot --path .
```

`godot --path . -- --demo` startuje z włączonym botem, a `-- --lang pl`
wybiera język na jedno uruchomienie.

## Języki

Gra jest domyślnie po angielsku, z polskim do wyboru (klawisz L, wybór
zapisuje się w `user://settings.cfg`). Wszystkie teksty są w
[i18n/strings.csv](i18n/strings.csv): kolumna `keys`, potem `en` i `pl`.
Nowy tekst w grze = nowy wiersz tam i `tr("KLUCZ")` w kodzie; test
`tests/test_i18n.gd` pilnuje, żeby każdy klucz miał oba języki, a czcionka
wszystkie znaki. Po zmianie CSV trzeba raz uruchomić `--import`.

Czcionka: Jersey 10 (OFL), zawsze ostra; tekst tylko w rozmiarach 16, 20 i 32 px
(`S`, `M`, `L` w `ui/room_view.gd`), bo mniejsze gubią litery.

| Klawisz | Akcja |
|---------|-------|
| W / S, strzałki, kółko myszy | wybór pary sąsiadów |
| SPACJA, klik w wybraną parę | zamiana |
| F | wpuść następny element teraz |
| M | dopływ: co 3 ruchy albo co 6 s |
| D | demo: bot gra sam |
| R / N | ten sam pokój od nowa / nowy pokój |
| C | efekt CRT włącz / wyłącz |
| L | język: English / polski (zapamiętywany) |
| H | karta sterowania |
| F11 | pełny ekran |
| ESC | wyjście |

## Stan: etap 2 (jeden grywalny pokój)

Pokój Bubble: 8 slotów, 45 ruchów, cel 5000, 3 życia, dwa przedmioty
(Sito Eratostenesa i Bubble Pump). Gra rysuje w 640×360 i skaluje obraz
całkowitą wielokrotnością, z shaderem CRT (`ui/crt.gdshader`).

- `core/room_session.gd`: dopływ (czas albo ruchy, do porównania w grze),
  życia, uzupełnianie trójką, gdy zostaje najwyżej jeden element.
- `ui/main.gd`: obraz 640×360 w SubViewport, skalowanie, CRT, wejście.
- `ui/room_view.gd`: plansza, panele, animacje (łuk przy zamianie, wypływanie
  ogniwo po ogniwie, punkty × mnożnik, błysk aktywnego przedmiotu).
- `sim/sim_rooms.gd`: bot gra 400 seedów, wynik do balansu celu.

Wyniki symulacji (bot bez błędów, 45 ruchów, mediana): ~3800 bez przedmiotów,
~12 000 z Sitem i Bubble Pumpem.

```bash
godot --headless --path . -s res://sim/sim_rooms.gd
```

## Rdzeń (etap 1)

Logika gry to zwykłe klasy (`RefCounted`), bez scen i okna, więc da się ją
testować i symulować.

| Plik | Co robi |
|------|---------|
| `core/board.gd`, `core/element.gd` | tablica elementów z pojemnością |
| `core/events.gd`, `core/event_bus.gd` | nazwy zdarzeń i szyna zdarzeń (kolejność = kolejność slotów) |
| `core/room.gd` | pokój: ruchy, budżet, zaliczanie, łańcuchy, wynik, wygrana/przegrana, dopływ |
| `core/score_context.gd`, `core/move_context.gd` | to, co przedmioty mogą zmieniać (punkty × mnożnik, koszt ruchu) |
| `core/algorithms/bubble.gd` | zamiana sąsiadów, największy wypływa górą |
| `core/algorithms/insertion.gd` | wstawianie klucza, każde przesunięcie kosztuje 1, najmniejszy wychodzi z lewej |
| `core/data_gen.gd` | dane startowe: losowe, prawie posortowane, odwrócone, duplikaty |
| `core/number_props.gd` | parzyste, pierwsze, potęgi dwójki, Fibonacci, kwadraty |
| `core/items/` | przedmiot jako dane + reakcje na zdarzenia; pierwsze 4 przedmioty |

Wspólna zasada wszystkich algorytmów: element przy wyjściu znika i punktuje,
gdy jest skrajny (największy w Bubble, najmniejszy w Insertion). Kilka
zaliczeń po jednym ruchu to łańcuch. Wynik zaliczenia = `wartość × 10 × mnożnik`,
gdzie mnożnik startuje od numeru ogniwa łańcucha (maks. 8), a przedmioty
dodają do punktów albo mnożnika.

## Testy

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

Pierwsza komenda jest potrzebna tylko raz i po dodaniu nowej klasy
(`class_name`). Kod wyjścia 0 = wszystko przeszło. Test pada przy nieudanym
sprawdzeniu albo przy każdym błędzie silnika w czasie jego działania.

## Assety

Każdy asset z zewnątrz ma wpis w [CREDITS.md](CREDITS.md).
