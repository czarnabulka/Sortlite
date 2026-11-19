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

`godot --path . -- --demo` startuje z włączonym botem, `-- --lang pl`
wybiera język na jedno uruchomienie, a `-- --seed 123` odtwarza run.

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
| W / S, strzałki, kółko myszy | wybór pary (Bubble) albo miejsca dla klucza (Insertion) |
| SPACJA, klik w wybrane | zamiana / wstawienie |
| F | wpuść następny element teraz |
| I | karta zasad pokoju (pokazuje się sama przy pierwszym pokoju danego algorytmu) |
| A / D, klik | wybór przedmiotu między pokojami; SPACJA bierze |
| S / R / E | między pokojami: pomiń (+bity), przelosuj ofertę, ulecz życie |
| M | dopływ: co N ruchów albo co 6 s |
| D | demo: bot gra sam |
| R | nowy run (na ekranie końca) |
| C | efekt CRT włącz / wyłącz |
| L | język: English / polski (zapamiętywany) |
| H | karta sterowania |
| F11 | pełny ekran |
| ESC | wyjście |

## Stan: etap 3 (mini-run)

Run to jedno piętro z 4 pokojami: walka Bubble i walka Insertion (w losowej
kolejności), elita na odwróconych danych i boss **Adwersarz**, który dokłada
zawsze najgorszy możliwy element. Przed każdym pokojem wybierasz 1 z 3
przedmiotów (maks. 5, kolejność = kolejność działania). Życia przechodzą
między pokojami. Za pokój dostajesz bity (+1 za każde 5 niewydanych ruchów):
2 bity przelosowują ofertę, 5 leczy życie, pominięcie przedmiotu daje 3.

- `core/run.gd`: plan piętra (tabela `ROOMS`), nagrody, bity, życia.
- `core/items/catalog.gd`: 10 przedmiotów, m.in. Sito, Bit parzystości,
  Spirala Fibonacciego, Wieża potęg, Reaktor łańcuchowy, Bezpiecznik,
  Wyszukiwanie binarne (tylko Insertion).
- `core/bots/bots.gd`: idealny gracz dla każdego algorytmu (demo, sim, testy).
- `ui/run_view.gd`: wybór przedmiotu z mapą piętra, koniec runu, przejścia
  między ekranami (przyciemnienie) i animacje wejścia.
- `ui/anim.gd`: easingi i pomocnicze funkcje animacji.
- `ui/room_view.gd`: pokój dla obu algorytmów. W Insertion posortowana część
  rośnie od góry (zielona klamra), złoty klucz wstawiasz w wybrane miejsce,
  a koszt (przesunięcia) widać obok.

### Balans

`sim/sim_rooms.gd` gra każdym typem pokoju z `Run.ROOMS` na 300 seedach
(bot bez błędów, bez celu) i pokazuje, jak często pokonałby cel. Cele są
ustawione na około połowę mediany bota bez przedmiotów, bo człowiek gra wolniej
i myli się. Stan na teraz (bez przedmiotów): walki 88–100%, elity 92–100%,
boss 76%.

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
| `core/algorithms/insertion.gd` | wstawianie klucza, każde przesunięcie kosztuje 1, najmniejszy wychodzi pierwszy |
| `core/data_gen.gd` | dane startowe: losowe, prawie posortowane, odwrócone, duplikaty |
| `core/number_props.gd` | parzyste, pierwsze, potęgi dwójki, Fibonacci, kwadraty |
| `core/items/` | przedmiot jako dane + reakcje na zdarzenia |

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
