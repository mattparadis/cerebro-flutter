# TODO — Review delle skill Flutter UI/UX e di ui_map

Obiettivo: guidare la creazione di applicazioni Flutter curate nel design e corrette nei comportamenti UI/UX, con verifiche che distinguano ciò che è dimostrato da ciò che resta da controllare.

Questo documento raccoglie i problemi della review, le soluzioni proposte e i criteri per considerarli risolti. Le attività non sono ancora implementate.

## Evidenze della review

- I 23 test esistenti di `packages/ui_map` passano.
- Una nuova cattura della demo con esplorazione ha completato 48 screenshot senza errori di cattura.
- Il pulsante `Next` dell'onboarding cambia pagina tramite `PageController.nextPage`, ma l'esplorazione lo classifica come `none`.
- Una verifica mirata conferma che `sampleBackground` può restituire `null` per testo `#F0F0F0` su bianco, nonostante un contrasto inferiore a 1,2:1.
- Una verifica mirata conferma che un `SizedBox(height: 8)` seguito da un `IconButton` fratello produce un falso `small-icon-button`.
- Una verifica mirata conferma che `classifyEdge` restituisce `none` per una navigazione alla stessa location anche quando aumenta la profondità dello stack.

## P1 — Rendere attendibili le conclusioni dell'audit

### 1. Separare osservazioni, sospetti, difetti e limiti della verifica

- [x] Correggere le istruzioni che dichiarano automaticamente confermati `dead_taps`, warning del lint e problemi dell'ambiente di cattura. *(fatto 2026-11-08: stati `confirmed/suspected/not_checked/capture_issue` nella skill e nel template; sezione Capture limits in MAP.md; regola sui target annidati)*

**Problema:** `audit-screens` attribuisce certezza a segnali che possono dipendere da osservazioni incomplete. Anche un errore della factory o una dipendenza non simulata può diventare impropriamente un difetto dell'app.

**Come risolvere:**

- Definire uno schema comune per tool e report: osservazione, origine dell'evidenza, stato della verifica, impatto, posizione e passo necessario per confermare il problema.
- Usare stati distinti: `confirmed`, `suspected`, `not_checked`, `capture_issue`. Registrare separatamente le osservazioni grezze.
- Mantenere separati gravità e certezza: un problema potenzialmente grave può essere ancora da verificare.
- Trattare il lint come segnalazione da contestualizzare, salvo regole capaci di dimostrare precisamente il difetto.
- Separare errori dell'app riprodotti da errori della factory, dei mock, dei font o del runtime di test.
- Aggiornare la regola «solo screenshot e semantica»: ammettere anche codice, test di interazione e misure, dichiarandone la provenienza.
- Non dichiarare automaticamente sicuro un target piccolo solo perché contenuto in un target grande: verificare che il target esterno offra la stessa azione.

**Criteri di completamento:**

- Un mock mancante viene riportato come limite della cattura, senza attribuire automaticamente un difetto UX all'app.
- Ogni finding confermato include un'evidenza riproducibile.
- Report e riepilogo distinguono difetti, sospetti e copertura mancante.

**File:** `skills/audit-screens/SKILL.md`, `skills/audit-screens/references/report-template.md`, `packages/ui_map/lib/src/map_writer.dart`.

### 2. Correggere l'esplorazione delle interazioni e della navigazione

- [x] Sostituire l'equivalenza «nessuna navigazione/overlay = azione non funzionante». *(fatto 2026-11-08: `no_observed_effect` + `state_change` via fingerprint della semantica; profondità prima della location in `classifyEdge`. Rimandati: observer multi-Navigator, scenari con risultati attesi)*

**Problema:** filtri, espansioni, selezioni, aggiornamenti locali e pagine di onboarding possono funzionare senza cambiare URL. Profondità dello stack e URL non identificano con certezza l'operazione di navigazione eseguita.

**Come risolvere:**

- Rinominare `none`/`dead_taps` in termini osservativi, per esempio `no_observed_effect`, mantenendo una migrazione documentata del formato.
- Rilevare prima/dopo anche stato semantico, contenuto e overlay, oltre alla destinazione e allo stack.
- Considerare un cambiamento visivo un indizio, non una prova di successo: un'animazione può cambiare pixel senza completare l'azione.
- Permettere scenari con risultati attesi espliciti: pagina attiva, filtro selezionato, elemento espanso, dato persistito, destinazione raggiunta.
- Usare observer o snapshot delle pagine dei Navigator pertinenti, incluse le shell, per osservare le transizioni. Non dedurre il nome del metodo chiamato dalla sola variazione di profondità.
- Gestire la stessa location con stack cambiato prima del caso «nessun cambiamento».
- Verificare il comportamento del ritorno sia da navigazione interna sia da apertura diretta.
- Dichiarare limiti dell'esplorazione: target non visitati, limite di tap, contenuto fuori viewport, piattaforme e varianti non esplorate.

**Criteri di completamento:**

- `Next` della demo non viene più dichiarato un pulsante non funzionante.
- Fixture per filtro, espansione, selezione, stessa location su nuovo stack e navigazione dentro shell producono risultati corretti.
- Un callback realmente vuoto resta rilevabile, con evidenza appropriata.
- La skill di build non richiede più che ogni pulsante navighi o apra un overlay.

**File:** `packages/ui_map/lib/src/edges.dart`, `packages/ui_map/lib/src/driver.dart`, `packages/ui_map/lib/src/capture.dart`, entrambe le skill.

### 3. Ridurre i falsi positivi del lint

- [x] Correggere le regole basate sulla vicinanza di righe e chiarire il significato dei warning. *(fatto 2026-11-08: `small-icon-button` sulla lista argomenti bilanciata e `child: IconButton`; severità `convention` per colori e fontSize; `// ui_map: ignore`. Non fatto: AST completo)*

**Problema:** il lint interpreta un `SizedBox(height: 8)` vicino a un `IconButton` come un vincolo del pulsante, anche quando sono fratelli. La presenza di un colore o di un font size letterale non dimostra da sola un difetto visibile.

**Come risolvere:**

- Usare l'AST Dart per le regole che dipendono da parentela, callback o struttura del widget.
- Per `small-icon-button`, verificare la relazione effettiva tra vincolo e pulsante; usare la cattura per confermare la dimensione risultante.
- Classificare colori e dimensioni letterali come possibili violazioni delle convenzioni del progetto, senza equipararli automaticamente a problemi di accessibilità.
- Consentire eccezioni locali documentate, oltre alla disabilitazione globale delle regole.
- Allineare il requisito di build «zero warning» alla nuova distinzione fra problemi confermati ed eccezioni motivate.

**Criteri di completamento:** il caso di widget fratelli non genera più il warning; un pulsante realmente vincolato a 32×32 viene ancora segnalato; commenti e stringhe non generano falsi finding strutturali.

**File:** `packages/ui_map/lib/src/lint.dart`, `packages/ui_map/test/lint_test.dart`, entrambe le skill.

### 4. Correggere il contratto e la copertura del controllo del contrasto

- [x] Eliminare l'affermazione «tutto ciò che non compare in low_contrast ha superato il controllo». *(fatto 2026-11-08: campionamento dello sfondo corretto per testo quasi uguale allo sfondo; `contrast_coverage` e `contrast_not_measurable` con motivo; checklist e material3 aggiornate. Rimandati: span multistile misurati singolarmente, testo editabile, passaggio di rendering dedicato)*

**Problema:** il campionamento può saltare proprio testi molto simili allo sfondo. La scansione dei soli `RichText`, con un solo stile per paragrafo, non copre tutto il testo renderizzato. Stati disabilitati e altre esenzioni non vengono distinti esplicitamente.

**Come risolvere:**

- Registrare per ogni elemento `pass`, `fail`, `not_measurable` o `exempt`, con motivo e metodo di misura.
- Esportare copertura: elementi individuati, misurati, saltati ed esclusi. L'assenza da `low_contrast` non deve mai significare da sola «pass».
- Correggere il campionamento per non scartare lo sfondo solo perché simile al testo. Quando non è possibile distinguerlo affidabilmente, restituire `not_measurable`.
- Valutare un passaggio di rendering dedicato allo sfondo per i casi supportati, con fixture che verifichino che il layout resti identico.
- Misurare i singoli span con stili diversi e definire il supporto per testo editabile, opacità degli antenati, clipping, gradienti e immagini. Esplicitare i casi non supportati.
- Distinguere componenti disabilitati, testo decorativo e altre esenzioni pertinenti senza esentare automaticamente testo informativo.
- Verificare e documentare la conversione fra dimensioni Flutter, scala effettiva e soglie WCAG per testo grande; non assumere equivalenza numerica fra unità diverse.
- Rimuovere dalle reference le garanzie assolute di contrasto dei token, soprattutto in presenza di override del tema.

**Criteri di completamento:**

- `#F0F0F0` su bianco non viene più implicitamente considerato conforme.
- Fixture coprono testo multistile, testo editabile, opacità, sfondi variabili e controlli disabilitati.
- Report e checklist distinguono esplicitamente misura riuscita e copertura mancante.

**File:** `packages/ui_map/lib/src/contrast.dart`, `packages/ui_map/lib/src/capture.dart`, `skills/audit-screens/references/checklist.md`, `skills/design-screen/references/material3.md`.

**Riferimento:** [W3C — Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

## P1 — Progettare e verificare flussi completi

### 5. Aggiungere contratti di comportamento ai flussi

- [ ] Estendere il brief e il build mode oltre stati statici e destinazioni di navigazione.

**Problema:** una schermata può essere corretta e un pulsante può navigare, mentre il compito dell'utente non viene completato. Un «Salva» che chiude senza persistere i dati non deve superare la verifica.

**Come risolvere:**

- Per ogni flusso importante, definire una tabella: situazione iniziale → azione → risultato atteso → feedback → recupero dall'errore.
- Specificare dove vive lo stato, quando viene persistito e cosa deve rimanere dopo back, cambio tab o riapertura.
- Coprire, quando pertinenti: modifiche non salvate, annullamento, bozza, doppio tap, richiesta in corso, errore, retry e prevenzione di operazioni duplicate.
- Coprire conservazione di scroll e filtri, permessi negati, percorso alternativo e autenticazione con ritorno al deep link originario.
- Aggiungere widget test per transizioni verificabili localmente e integration test per i percorsi che dipendono dal dispositivo.
- Verificare esiti di dominio con repository fake osservabili: per esempio che «Salva» inserisca davvero il dato e che questo compaia al ritorno nella lista.
- Riportare separatamente ciò che è verificato con fake e ciò che richiede backend o plugin reali.

**Criteri di completamento:** almeno un flusso di creazione dimostra salvataggio, errore/retry, annullamento e protezione dal doppio invio; almeno un flusso autenticato conserva la destinazione originaria.

**File:** `skills/design-screen/SKILL.md`, `skills/design-screen/references/patterns.md`, `skills/audit-screens/references/checklist.md`, fixture della demo.

### 6. Rendere riproducibili gli scenari tramite fixture

- [x] Affiancare alle varianti URL un modo per preparare dati e dipendenze di test. *(fatto 2026-11-08: `scenarios` + `resetScenario` nella factory, `routes.<path>.scenarios` e `default_scenario` nel yaml, id `__s-<nome>`, reset prima di ogni schermata e di ogni tap esplorato; demo: scenario `empty` pixel-identico alla variante URL)*

**Problema:** `?state=empty|loading|error` può mostrare una schermata senza dimostrare la transizione reale fra stati. Molte app non espongono questi parametri.

**Come risolvere:**

- Definire scenari nominati nella factory di test, con repository fake e override delle dipendenze secondo l'architettura dell'app.
- Preparare loading, successo, vuoto, errore, offline e dati parziali attraverso le dipendenze; mantenere le varianti URL dove sono già appropriate.
- Resettare dati e stato fra scenari per evitare contaminazioni.
- Collegare gli scenari ai contratti di comportamento e alle catture.
- Rendere espliciti gli stati non configurati, senza confonderli con stati assenti nell'app.

**Criteri di completamento:** una schermata senza parametri `state` viene catturata nei suoi stati attraverso fake; un retry può passare realmente da errore a successo nel test.

## P2 — Rafforzare le decisioni di design

### 7. Arricchire il brief con una direzione visiva motivata

- [ ] Superare il solo punto di partenza seed color + gutter + componenti Material.

**Problema:** le regole attuali favoriscono ordine e coerenza, ma possono produrre app visivamente simili. Evitare cliché non basta a costruire un'identità.

**Come risolvere:**

- Aggiungere al brief pubblico, contesto d'uso, priorità informative, densità e carattere visivo desiderato.
- Derivare dal brief poche scelte concrete su tipografia, immagini, gerarchia, colore e composizione.
- Per app esistenti, distinguere convenzioni da preservare e problemi da correggere: copiare uno schermo vicino non deve propagare difetti.
- Per app nuove o redesign ampi, scegliere riferimenti pertinenti e spiegare quali principi adottare.
- Valutare i prototipi rispetto a obiettivi dichiarati: leggibilità, rapidità del compito, densità, riconoscibilità e adattamento ai contenuti reali.
- Convertire i divieti estetici in segnali da valutare nel contesto. Gradienti, composizioni centrate e più accenti non sono difetti automatici.

**Criteri di completamento:** ogni direzione proposta ha una motivazione legata agli utenti e ai contenuti; i prototipi differiscono per scelte utili al compito; le eccezioni estetiche sono ammesse quando motivate.

**File:** `skills/design-screen/SKILL.md`, `skills/design-screen/references/anti-patterns.md`, `skills/design-screen/references/material3.md`.

### 8. Distinguere requisiti, default ed eccezioni

- [x] Rivedere gli assoluti e risolvere le contraddizioni tra reference e checklist. *(fatto 2026-11-08: legenda requisito/default/contesto in design-screen e nelle reference; strategia adattiva Material+`.adaptive` ammessa; politica di validazione dei form; `go` su route figlia vs top-level giudicato dal pop osservato; `min_tap_size` per piattaforma nel tool)*

**Come risolvere:**

- Etichettare le indicazioni come requisito verificabile, default consigliato o scelta dipendente dal contesto.
- Eliminare il divieto assoluto di combinare Material e Cupertino: documentare una strategia adattiva coerente, inclusi i componenti `.adaptive` dentro shell Material.
- Nei form scegliere esplicitamente la politica di validazione. Come default, permettere un submit che mostri gli errori; disabilitare durante invio o quando esiste una precondizione spiegata. Se si disabilita fino alla validità, rendere comprensibile come soddisfare i requisiti.
- Per `go`/`push`, descrivere stack e ritorno attesi; non dichiarare errata un'API senza considerare la configurazione delle route.
- Trattare numero di azioni, dimensioni tipografiche, spaziature e composizioni come default adattabili quando non sono vincoli effettivi.
- Allineare regole iOS/Android e soglie del tool: il minimo dei target deve seguire il profilo scelto, senza un unico valore globale implicitamente valido per tutte le piattaforme.
- Rendere le correzioni richieste verificabili; riportare onestamente problemi non risolti, evitando formulazioni che possano indurre a dichiararli corretti senza prova.

**Criteri di completamento:** le reference non prescrivono e vietano la stessa combinazione; ogni form ha una politica attuabile; le valutazioni di navigazione dipendono dal comportamento osservato.

**File:** entrambe le skill e le relative reference.

**Riferimenti:** [Flutter Switch.adaptive](https://api.flutter.dev/flutter/material/Switch/Switch.adaptive.html), [go_router Navigation](https://pub.dev/documentation/go_router/latest/topics/Navigation-topic.html).

## P2 — Ampliare e dichiarare la copertura delle verifiche

### 9. Definire una matrice minima proporzionata al progetto

- [x] Rendere obbligatoria una scelta esplicita di dispositivi, piattaforme, accessibilità e contenuti da verificare. *(fatto 2026-11-08: blocco `coverage` con `not_executed` in map.json e MAP.md; profili quick/extended; cattura con tastiera (`keyboard: true`, `__kb`) e `locales`; `references/device-checks.md` con 13 controlli su dispositivo. Non fatto: RTL automatico oltre al locale, testi lunghi generati)*

**Problema:** il setup predefinito usa un telefono Android e testo a scala 1.0. La skill verifica 1.3 solo quando già configurato. Questo non sostiene una promessa generale di correttezza mobile.

**Come risolvere:**

- Prevedere un profilo rapido e uno esteso, scegliendo combinazioni motivate invece del prodotto cartesiano di tutte le varianti.
- Includere un telefono piccolo, dimensione rappresentativa, temi supportati e piattaforme effettivamente distribuite.
- Verificare testo molto grande, includendo per esempio 2.0 come controllo aggiuntivo; dichiarare i limiti della simulazione rispetto allo scaling reale della piattaforma.
- Aggiungere scenari con tastiera aperta, campo focalizzato, CTA raggiungibile e contenuto scorrevole.
- Usare testi lunghi, dati realistici, localizzazioni supportate e RTL quando pertinente.
- Controllare contenuti fuori dalla prima viewport e stati raggiungibili solo dopo interazione.
- Indicare nel report combinazioni eseguite, escluse e non supportate.
- Definire una lista di prove su dispositivo: TalkBack/VoiceOver, focus, annunci, gesture back, tastiera reale, plugin, haptics e movimento ridotto.

**Criteri di completamento:** i report mostrano una copertura esplicita; la skill non dichiara verificata una piattaforma o una condizione mai eseguita; i controlli manuali hanno passi e risultati attesi.

**File:** `packages/ui_map/lib/src/config.dart`, `packages/ui_map/lib/src/templates.dart`, `packages/ui_map/lib/src/capture.dart`, entrambe le skill.

**Riferimento:** [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility).

### 10. Rafforzare la definizione di regressione

- [x] Estendere `check` oltre gli aumenti nei conteggi di errori e target piccoli. *(fatto 2026-11-08: finding confrontati per identità (label/testo + dimensione o ratio), classi regression / coverage loss / improvement / visual / semantics, `--fail-on coverage`; test con difetto risolto + nuovo a conteggio invariato)*

**Problema:** `ScreenChange.isRegression` non considera peggioramenti del contrasto. Un difetto può sparire e un altro comparire mantenendo invariato il conteggio, senza essere classificato come regressione.

**Come risolvere:**

- Confrontare i finding per identità stabile e tipo, non soltanto per numero. Preferire identificatori semantici espliciti dove disponibili, con fallback dichiarati.
- Includere nuovi problemi confermati di contrasto, accessibilità e comportamento negli ambiti supportati.
- Distinguere regressione funzionale, variazione visiva e perdita di copertura.
- Segnalare separatamente route rimosse, capture mancanti e misure prima disponibili ora non misurabili; rendere configurabile la politica di blocco.
- Mantenere configurabili le soglie di CI e documentare esattamente ciò che il comando può bloccare.
- Usare hash e differenze di immagine per segnalare cambiamenti, senza equiparare automaticamente ogni cambiamento a peggioramento.

**Criteri di completamento:** una fixture con un vecchio difetto risolto e uno nuovo a conteggio invariato segnala il nuovo problema; il peggioramento del contrasto viene riconosciuto; una perdita di copertura non appare come successo silenzioso.

**File:** `packages/ui_map/lib/src/diff.dart`, `packages/ui_map/bin/ui_map.dart`, `packages/ui_map/test/diff_test.dart`, `README.md`.

## Ordine di implementazione proposto

1. Correggere subito le affermazioni di certezza nelle skill e nella checklist, insieme alla terminologia dei risultati.
2. Correggere i casi riprodotti di contrasto, lint ed esplorazione, aggiungendo fixture di regressione mirate.
3. Introdurre contratti dei flussi e scenari con dipendenze controllate.
4. Rafforzare il brief visivo e rendere coerenti requisiti, default ed eccezioni.
5. Ampliare la matrice di verifica e aggiornare le politiche di `check`.
6. Rivalutare le skill su app diverse dalla demo, includendo un caso con form e dati remoti e uno con comportamento adattivo iOS/Android.

## Elementi da preservare

- [ ] Mantenere il ciclo implementazione → screenshot → ispezione → correzione.
- [ ] Mantenere la progettazione esplicita degli stati e il confronto light/dark.
- [ ] Mantenere l'uso di tema e convenzioni dell'app, consentendo correzioni motivate.
- [ ] Mantenere prototipi distinti nella struttura e nei compromessi.
- [ ] Mantenere report con evidenze, impatto per l'utente e correzioni Flutter concrete.
