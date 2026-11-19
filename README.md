# Roguesort (tytuł roboczy)

Roguelite łamigłówkowy o sortowaniu, wychodzący z *Bubble Sort Quest*.
Porządkujesz liczby ruchami prawdziwych algorytmów, a przedmioty łączą się
w synergie jak w Isaacu i mnożą wynik jak w Balatro.

Dokument projektowy: https://claude.ai/artifact/5ETaojyCo7PVF7KUTtAXea

Silnik: **Godot 4.7**, GDScript.

## Stan: etap 1 (rdzeń bez grafiki)

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
