# DevOps zadatak - Izvodi

## Kontekst

Banka vodi račune više različitih organizacija. Svaka organizacija može imati više računa. Banka ima obavezu da generiše dnevne izvode za sve račune i da ih služi za download krajnjim korisnicima. Na kraju svakog dana, servis banke generiše dnevni izvod za sve račune koji se u njoj vode i kopira ih u određeni folder definisane strukture gde ih čuva najviše 2 meseca i služi putem Nginx web servera.

Račun organizacije je formata `<id-banke>-<partija>-<kontrolni-broj>`, npr. `840-0000000001620-53`. Svaki račun pripada tačno jednoj organizaciji, međutim neke organizacije mogu imati uvid u račune koji im ne pripadaju.

### Struktura foldera

1. Root folder `izvodi` na Linux serveru sadrži sub-folder za svaku organizaciju, imenovan po matičnom broju organizacije (MB)
1. Svaki MB folder sadrži listu datuma, imenovanih po ISO8601 formatu
1. U svakom datumu nalaze se partije računa koji pripadaju toj organizaciji, svaki imenovan `<partija>.<format>.zip` pri čemu:
    1. Partija ima tačno 13 numerika
    1. Format izvoda može biti PDF, JSON ili TXT i banka uvek pravi sve formate
    1. Zip arhiva sadrži tačno 1 fajl, po imenu `<partija>.<format>`
1. Bilo gde u hijerarhiji se mogu naći drugi fajlovi i direktorijumi i nije bitno koje su prirode, mogu se ignorisati
1. Folder svake organizacije sadrži fajl `<mb>_sve-partije.json` koji sadrži listu svih partija te organizacije koje banka vodi, kao i partije drugih organizacija u istoj banci u koja ova ima uvid i čiji izvodi se takođe nalaze u opisanoj strukturi foldera

Kao drvo, struktura izgleda na sledeći način:

```
izvodi/
  MB1/
    datum11/
        partijaN.pdf.zip
        partijaN.txt.zip
        partijaN.json.zip
        ...
        partijaM.pdf.zip
        ...
    datum12/
        partijaX.txt.zip
        ...
    MB1_partije.json
  MB2/
    datum21/
    ...
    MB2_partije.json
...
```

Pored navedenog, važe i sledeća pravila:

1. Izvod za bilo koju partiju se ne proizvodi ukoliko nije bilo aktivnosti tog dana na toj partiji
1. Folder za datum ne mora da postoji ako nijedna partija koja pripada datoj organizaciji nije imala aktivnost tog dana
1. Folder organizacije ne mora da postoji ako nije bilo aktivnosti nijedne partije te organizacije u protekla 2 meseca

### Struktura indeksa partija

Fajl `<mb>_partije.json` sadrži listu svih partija u koje organizacija sa matičnim brojem MB ima uvid kao i listu njenih sopstvenih partija (predstavlja indeks partija organizacije):

```
{
    "MB": [ "partija11", "partija12", ..., "partija1N"],
    "MBX": [ "partijaX1", "partijaX2", ..., "partijaXM"],
    ...
    "MBY": [ "partijaY1", ..., "partijaYJ" ]
}
```

Indeks lista organizacije i niz partija koje im pripadaju (nalaze se u njihovom folderu u ranije pomenutoj strukturi)

1. prvi navedeni MB je onaj od organizacije u čijem se folderu indeks partija nalazi (i koji se nalazi u imenu fajla)
    1. lista partija u nizu su uvek **sve** partije koje pripadaju toj organizaciji (izvodi ovih partija se nalaze u datumskim folderima te organizacije, ukoliko postoje na taj dan)
1. svi ostali MB predstavljaju druge organizacije koje imaju račune u istoj banci
    1. lista partija u nizu su uvek **subset** partija koje pripadaju tim drugim organizacijama, ali su date prvoj organizaciji na uvid

## Zadatak 1

Za svaku organizaciju, na bilo kakav način, kreirati novi **kompletan dnevni izvod** (KDI) koji predstavlja ZIP arhivu koja sadrži otpakovane sve dnevne izvode za konkretni datum. KDI sadrži sve sopstvene partije organizacije kao i "tuđe partije" u koje ta organizacija ima uvid, a imali su aktivnost tog dana:

**Fajl**: `MB_sve-partije.zip`:
```
partija1.pdf
partija1.txt
partija1.json
partija2.pdf
...
partijaN.pdf
...
```

1. Za organizaciju MB i datum, izvod se nalazi na putanji `mb/datum/mb_sve-partije.zip`
1. Arhiva sadrži sve formate svih partija koje su imale aktivnost, ukoliko postoje za taj dan, inače se ne pravi
1. Obezbediti idempotentnost
    1. Ponavljanje procesa bilo kada ne pravi razliku ako nije bilo promena fajl sistema
    2. Prekidanje operacije usred posla i ponovno pokretanje će nastaviti dalje obradu
    3. Obrisani KDI će biti rekreiran na ponovnom pokretanju
3. **Kritično je obezbediti da se greškom u KDI ne upakuju partije u koje organizacija nema uvid**

## Zadatak 2

Napraviti skriptu koja generiše mock navedene šeme podataka. Skripta bi se koristila za testiranje rešenja zadatka.

Skripta treba biti parametrizovana u što je većoj meri i da randomizuje podatke tako da oni zadovoljavaju navedene strukture.

## Pretpostavke

1. Alat/skript se izvršava na Linux serveru gde se nalaze izvodi i ima read/write prava pristupa root folderu izvoda
    1. Dizajniran je za upotrebu putem cron job-a
1. Instaliran je pwsh i podešen bez ikakvih ograničenja

## Dodatni zadaci

1. Napisati `README.md` o svrsi, funkcionalnostima, opisom parametara, preduslova, napomenama itd. (ciljna grupa IT)
1. Alat/skripta proizvodi detaljni log sprovedenih operacija

## Primer

U sledećem primeru prikazano je zbog konzciznosti samo nekoliko datuma, inače, ne postoji datum koji je stariji od 2 meseca.

```
izvodi/
  08926/
    2022-03-03/
      0000000026640.json.zip
      0000000026640.pdf.zip
      0000000026640.txt.zip
      0000001916740.json.zip
      0000001916740.pdf.zip
      0000001916740.txt.zip
    2022-02-28/
      0000001916740.json.zip
      0000001916740.pdf.zip
      0000001916740.txt.zip
      image.png
    2022-02-12/
      0000000026640.json.zip
      0000000026640.pdf.zip
      0000000026640.txt.zip
    08926_partije.json
  10523/
    2022-03-02/
      2340711181843.json.zip
      2340711181843.pdf.zip
      2340711181843.txt.zip
      2340731141843.json.zip
      2340731141843.pdf.zip
      2340731141843.txt.zip
      4073114184323.json.zip
      4073114184323.pdf.zip
      4073114184323.txt.zip
    2022-02-28/
      2340731241843.json.zip
      2340731241843.pdf.zip
      2340731241843.txt.zip
    2022-02-27/
      2340711181843.json.zip
      2340711181843.pdf.zip
      2340711181843.txt.zip
      2340714543843.json.zip
      2340714543843.pdf.zip
      2340714543843.txt.zip
      2340714547843.json.zip
      2340714547843.pdf.zip
      2340714547843.txt.zip
      2340731141843.json.zip
      2340731141843.pdf.zip
      2340731141843.txt.zip
      4073114184323.json.zip
      4073114184323.pdf.zip
      4073114184323.txt.zip
      notes.txt
    10523_partije.json
  12506/
    2022-02-01/
      5061224184323.txt.zip
      5061224184323.pdf.zip
      5061224184323.json.zip
    12506_partije.json
```

Fajl: `08926_partije.json`
```json
{
"08926": ["0000000026640", "0000001916740"],
"10523": ["2340711181843", "2340711182843", "2340711183843", "2340711184843", "2340731241843"]
}
```

U ovom primeru su prikazane 3 organizacije, sa MB `08926`, `10523` i `12506`. Organizacija sa MB `08926` ima svoje partije `0000000026640`, `0000001916740` i dat joj je uvid u 4 partije organizacije `10523`. U slučaju ove organizacije, rezultat zadatka su 3 KDI za tri navedena datuma sa sledećim sadržajem:

```
izvodi/08926/2022-03-03/08926_sve-partije.zip
  0000000026640.json
  0000000026640.pdf
  0000000026640.txt
  0000001916740.json
  0000001916740.pdf
  0000001916740.txt
izvodi/08926/2022-02-28/08926_sve-partije.zip
  0000001916740.json
  0000001916740.pdf
  0000001916740.txt
  2340731241843.json
  2340731241843.pdf
  2340731241843.txt
izvodi/08926/2022-02-12/08926_sve-partije.zip
  0000000026640.json
  0000000026640.pdf
  0000000026640.txt
```

Nakon što je operacija završena, svaka organizacija ima KDI za svaki dan, sem ako tog dana nije bilo aktivnosti.
