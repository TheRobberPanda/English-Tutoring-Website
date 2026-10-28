// Starter exercises for the practice area in cuenta.html.
//
// Static on purpose: this is content that changes with a commit, not with a
// click, and keeping it out of the database means no seed migration and no
// Storage/row budget spent on it. Paulo's own exercises live in the
// practice_items table instead and are merged in at runtime.
//
// Every exercise has a stable id; progress is stored per student as
// "s:<id>" in practice_progress. NEVER renumber or reuse an id — a student's
// spaced-repetition history would silently attach to a different exercise.
// Add new ones at the end of a list with a fresh id.
//
// Answers are lists of accepted alternatives. Matching ignores case, extra
// spaces and end punctuation, expands English contractions, and treats a
// missing accent as "almost" rather than wrong.

window.PRACTICE_DATA = (function () {
  // ---- English irregular verbs: base | past | participle | es | pl ----------
  // Alternatives inside a form are separated by "/".
  const EN_VERBS = `
be|was/were|been|ser, estar|być
become|became|become|convertirse, llegar a ser|stawać się
begin|began|begun|empezar|zaczynać
bite|bit|bitten|morder|gryźć
blow|blew|blown|soplar|dmuchać
break|broke|broken|romper|łamać, psuć
bring|brought|brought|traer|przynosić
build|built|built|construir|budować
buy|bought|bought|comprar|kupować
catch|caught|caught|atrapar, coger|łapać
choose|chose|chosen|elegir|wybierać
come|came|come|venir|przychodzić
cost|cost|cost|costar|kosztować
cut|cut|cut|cortar|ciąć, kroić
do|did|done|hacer|robić
draw|drew|drawn|dibujar|rysować
dream|dreamed/dreamt|dreamed/dreamt|soñar|śnić, marzyć
drink|drank|drunk|beber|pić
drive|drove|driven|conducir|prowadzić (samochód)
eat|ate|eaten|comer|jeść
fall|fell|fallen|caer|spadać, upadać
feel|felt|felt|sentir|czuć
fight|fought|fought|pelear, luchar|walczyć
find|found|found|encontrar|znajdować
fly|flew|flown|volar|latać
forget|forgot|forgotten|olvidar|zapominać
forgive|forgave|forgiven|perdonar|wybaczać
freeze|froze|frozen|congelar(se)|zamarzać
get|got|got/gotten|conseguir, recibir|dostawać
give|gave|given|dar|dawać
go|went|gone|ir|iść, jechać
grow|grew|grown|crecer|rosnąć
have|had|had|tener|mieć
hear|heard|heard|oír|słyszeć
hide|hid|hidden|esconder|chować, ukrywać
hit|hit|hit|golpear|uderzać
hold|held|held|sostener|trzymać
hurt|hurt|hurt|doler, hacer daño|boleć, ranić
keep|kept|kept|guardar, mantener|trzymać, zachowywać
know|knew|known|saber, conocer|wiedzieć, znać
lead|led|led|dirigir, guiar|prowadzić, przewodzić
learn|learned/learnt|learned/learnt|aprender|uczyć się
leave|left|left|irse, dejar|wychodzić, zostawiać
lend|lent|lent|prestar|pożyczać (komuś)
let|let|let|dejar, permitir|pozwalać
lose|lost|lost|perder|tracić, gubić
make|made|made|hacer, fabricar|robić, tworzyć
mean|meant|meant|significar, querer decir|znaczyć
meet|met|met|conocer, quedar con|spotykać, poznawać
pay|paid|paid|pagar|płacić
put|put|put|poner|kłaść
read|read|read|leer|czytać
ride|rode|ridden|montar (en bici, a caballo)|jeździć (na rowerze, konno)
ring|rang|rung|sonar, llamar|dzwonić
rise|rose|risen|subir, elevarse|wznosić się, rosnąć
run|ran|run|correr|biegać
say|said|said|decir|mówić, powiedzieć
see|saw|seen|ver|widzieć
sell|sold|sold|vender|sprzedawać
send|sent|sent|enviar|wysyłać
set|set|set|fijar, poner|ustawiać
shake|shook|shaken|sacudir, agitar|potrząsać
shoot|shot|shot|disparar|strzelać
show|showed|shown/showed|mostrar, enseñar|pokazywać
shut|shut|shut|cerrar|zamykać
sing|sang|sung|cantar|śpiewać
sink|sank|sunk|hundirse|tonąć
sit|sat|sat|sentarse|siedzieć, siadać
sleep|slept|slept|dormir|spać
speak|spoke|spoken|hablar|mówić
spend|spent|spent|gastar, pasar (tiempo)|wydawać, spędzać
stand|stood|stood|estar de pie|stać
steal|stole|stolen|robar|kraść
swim|swam|swum|nadar|pływać
take|took|taken|tomar, llevar|brać
teach|taught|taught|enseñar|uczyć (kogoś)
tear|tore|torn|romper, rasgar|drzeć
tell|told|told|decir, contar|mówić, opowiadać
think|thought|thought|pensar|myśleć
throw|threw|thrown|lanzar, tirar|rzucać
understand|understood|understood|entender|rozumieć
wake|woke|woken|despertar(se)|budzić (się)
wear|wore|worn|llevar puesto|nosić (ubranie)
win|won|won|ganar|wygrywać
write|wrote|written|escribir|pisać`;

  // ---- English prepositions: rule | sentence | answers ----------------------
  const EN_PREPS = `
time-in|I was born ___ 1995.|in
time-on|The meeting is ___ Monday.|on
time-at|See you ___ five o'clock.|at
time-on|My birthday is ___ the 3rd of May.|on
time-in|We usually go skiing ___ winter.|in
time-at|I can't sleep ___ night.|at
time-in|I always drink coffee ___ the morning.|in
place-in|She's ___ the kitchen.|in
place-on|The keys are ___ the table.|on
place-at|I'll wait for you ___ the bus stop.|at
place-on|They live ___ the third floor.|on
place-in|We arrived ___ London at midnight.|in
place-at|We arrived ___ the airport late.|at
dependent|I'm interested ___ photography.|in
dependent|It depends ___ the weather.|on
dependent|She's very good ___ languages.|at
dependent|I'm afraid ___ dogs.|of
dependent|Please listen ___ me.|to
dependent|Can you wait ___ me?|for
dependent|He's married ___ a teacher.|to
dependent|I'm looking forward ___ the holidays.|to
dependent|I need to think ___ it.|about
dependent|I'm tired ___ waiting.|of
dependent|Who is responsible ___ this project?|for
dependent|Your phone is different ___ mine.|from/to
dependent|Congratulations ___ your new job!|on
time-in|The train leaves ___ ten minutes.|in
since-for|I've lived here ___ 2019.|since
since-for|I've lived here ___ six years.|for
transport|We got ___ the bus and found a seat.|on
transport|I usually go to work ___ car.|by
transport|I usually go to work ___ foot.|on
transport|Can I pay ___ card?|by
dependent|I agree ___ you.|with
dependent|She asked ___ help.|for
dependent|I applied ___ the job last week.|for
dependent|This bag belongs ___ my sister.|to
dependent|They complained ___ the noise.|about
dependent|I'm proud ___ you.|of
dependent|The glass is full ___ water.|of
dependent|My job is similar ___ yours.|to
dependent|Don't be angry ___ me.|with/at
dependent|He's keen ___ football.|on
dependent|We're excited ___ the trip.|about
dependent|I'm worried ___ my exam.|about
dependent|I'm not used ___ getting up early.|to
place-on|She's been ___ holiday for two weeks.|on
place-on|What's ___ TV tonight?|on
place-on|I read it ___ the internet.|on
place-at|He works ___ a bank.|in/at
place-on|The picture ___ the wall is beautiful.|on
time-at|We always see my grandparents ___ Christmas.|at`;

  // ---- Spanish prepositions -------------------------------------------------
  const ES_PREPS = `
por-cause|Gracias ___ tu ayuda.|por
para-recipient|Este regalo es ___ ti.|para
a-direction|Mañana voy ___ Madrid.|a
en-place|Hoy estoy ___ casa.|en
de-origin|Soy ___ Polonia.|de
con|Quiero un café ___ leche.|con
para-purpose|Estudio ___ ser médico.|para
verb-prep|Siempre pienso ___ ti.|en
a-time|La clase empieza ___ las cinco.|a
de-origin|Trabajo ___ lunes a viernes.|de
para-deadline|Tengo que terminarlo ___ el viernes.|para
por-through|Paseamos ___ el parque.|por
verb-prep|¿Te acuerdas ___ mí?|de
verb-prep|Empiezo ___ trabajar a las nueve.|a
verb-prep|Dejé ___ fumar hace un año.|de
en-transport|Voy al trabajo ___ tren.|en
a-personal|Ayer visité ___ mi abuela.|a
verb-prep|Depende ___ ti.|de
verb-prep|Se enamoró ___ su vecina.|de
verb-prep|Me voy a casar ___ ella.|con
por-exchange|Lo compré ___ diez euros.|por
para-opinion|___ mí, el español es fácil.|para
por-means|Hablamos ___ teléfono cada día.|por
por-time|Salgo a correr ___ la mañana.|por
verb-prep|Sueño ___ vivir en España.|con
verb-prep|Esta tarta sabe ___ chocolate.|a
por-cause|Llegué tarde ___ el tráfico.|por
desde|Vivo aquí ___ hace tres años.|desde
en-place|La reunión es ___ la oficina.|en
de-origin|Es la casa ___ mis padres.|de
por-time|Tengo clase ___ la tarde.|por/en
verb-prep|Ella trabaja ___ profesora.|de
en-transport|Fuimos ___ coche hasta Cracovia.|en
para-purpose|Este libro es ___ aprender vocabulario.|para
verb-prep|Estoy cansado ___ trabajar tanto.|de
por-cause|Gracias ___ venir.|por`;

  // ---- Spanish verbs --------------------------------------------------------
  // Irregular: infinitive | en | pl | present (6) | preterite (6)
  const ES_IRREGULAR = `
ser|to be (permanent)|być|soy,eres,es,somos,sois,son|fui,fuiste,fue,fuimos,fuisteis,fueron
estar|to be (state, place)|być (stan, miejsce)|estoy,estás,está,estamos,estáis,están|estuve,estuviste,estuvo,estuvimos,estuvisteis,estuvieron
ir|to go|iść, jechać|voy,vas,va,vamos,vais,van|fui,fuiste,fue,fuimos,fuisteis,fueron
tener|to have|mieć|tengo,tienes,tiene,tenemos,tenéis,tienen|tuve,tuviste,tuvo,tuvimos,tuvisteis,tuvieron
hacer|to do, to make|robić|hago,haces,hace,hacemos,hacéis,hacen|hice,hiciste,hizo,hicimos,hicisteis,hicieron
poder|can, to be able to|móc|puedo,puedes,puede,podemos,podéis,pueden|pude,pudiste,pudo,pudimos,pudisteis,pudieron
querer|to want|chcieć|quiero,quieres,quiere,queremos,queréis,quieren|quise,quisiste,quiso,quisimos,quisisteis,quisieron
decir|to say, to tell|mówić, powiedzieć|digo,dices,dice,decimos,decís,dicen|dije,dijiste,dijo,dijimos,dijisteis,dijeron
venir|to come|przychodzić|vengo,vienes,viene,venimos,venís,vienen|vine,viniste,vino,vinimos,vinisteis,vinieron
poner|to put|kłaść|pongo,pones,pone,ponemos,ponéis,ponen|puse,pusiste,puso,pusimos,pusisteis,pusieron
saber|to know (facts)|wiedzieć|sé,sabes,sabe,sabemos,sabéis,saben|supe,supiste,supo,supimos,supisteis,supieron
salir|to go out, to leave|wychodzić|salgo,sales,sale,salimos,salís,salen|salí,saliste,salió,salimos,salisteis,salieron
dar|to give|dawać|doy,das,da,damos,dais,dan|di,diste,dio,dimos,disteis,dieron
ver|to see|widzieć|veo,ves,ve,vemos,veis,ven|vi,viste,vio,vimos,visteis,vieron
conocer|to know (people, places)|znać|conozco,conoces,conoce,conocemos,conocéis,conocen|conocí,conociste,conoció,conocimos,conocisteis,conocieron
pedir|to ask for, to order|prosić, zamawiać|pido,pides,pide,pedimos,pedís,piden|pedí,pediste,pidió,pedimos,pedisteis,pidieron
dormir|to sleep|spać|duermo,duermes,duerme,dormimos,dormís,duermen|dormí,dormiste,durmió,dormimos,dormisteis,durmieron
jugar|to play|grać|juego,juegas,juega,jugamos,jugáis,juegan|jugué,jugaste,jugó,jugamos,jugasteis,jugaron
pensar|to think|myśleć|pienso,piensas,piensa,pensamos,pensáis,piensan|pensé,pensaste,pensó,pensamos,pensasteis,pensaron
volver|to come back|wracać|vuelvo,vuelves,vuelve,volvemos,volvéis,vuelven|volví,volviste,volvió,volvimos,volvisteis,volvieron
traer|to bring|przynosić|traigo,traes,trae,traemos,traéis,traen|traje,trajiste,trajo,trajimos,trajisteis,trajeron
empezar|to start|zaczynać|empiezo,empiezas,empieza,empezamos,empezáis,empiezan|empecé,empezaste,empezó,empezamos,empezasteis,empezaron`;

  // Regular, no spelling changes in either tense: infinitive | en | pl
  const ES_REGULAR = `
hablar|to speak|mówić
trabajar|to work|pracować
estudiar|to study|uczyć się
comprar|to buy|kupować
escuchar|to listen|słuchać
mirar|to look|patrzeć
cocinar|to cook|gotować
bailar|to dance|tańczyć
viajar|to travel|podróżować
cantar|to sing|śpiewać
comer|to eat|jeść
beber|to drink|pić
aprender|to learn|uczyć się
vender|to sell|sprzedawać
correr|to run|biegać
vivir|to live|mieszkać, żyć
escribir|to write|pisać
abrir|to open|otwierać
recibir|to receive|otrzymywać
compartir|to share|dzielić się`;

  const ES_ENDINGS = {
    ar: { pres: ['o', 'as', 'a', 'amos', 'áis', 'an'], pret: ['é', 'aste', 'ó', 'amos', 'asteis', 'aron'] },
    er: { pres: ['o', 'es', 'e', 'emos', 'éis', 'en'], pret: ['í', 'iste', 'ió', 'imos', 'isteis', 'ieron'] },
    ir: { pres: ['o', 'es', 'e', 'imos', 'ís', 'en'], pret: ['í', 'iste', 'ió', 'imos', 'isteis', 'ieron'] }
  };
  const ES_PERSONS = ['yo', 'tú', 'él / ella', 'nosotros', 'vosotros', 'ellos / ellas'];

  // ---- Translation: prompt | answers ("/" separates alternatives) -----------
  // Sentences are the same everyday situations across every language pair,
  // so a student who switches direction is practising the same ideas.
  const TR_ES_EN = `
Tengo hambre.|I'm hungry.
¿Cuántos años tienes?|How old are you?
Hoy hace frío.|It's cold today./Today it's cold.
Me gusta leer antes de dormir.|I like reading before bed./I like to read before bed./I like reading before I go to sleep./I like to read before I go to sleep./I like reading before sleeping.
Llevo tres años viviendo en Polonia.|I've been living in Poland for three years./I've lived in Poland for three years.
¿Puedes repetirlo, por favor?|Can you repeat that, please?/Could you repeat that, please?/Can you repeat it, please?/Could you repeat it, please?
No sé qué decir.|I don't know what to say.
Estoy buscando trabajo.|I'm looking for a job./I'm looking for work.
Ayer fui al médico.|I went to the doctor yesterday./Yesterday I went to the doctor./I went to the doctor's yesterday.
¿A qué te dedicas?|What do you do?/What do you do for a living?
Tengo que irme.|I have to go./I've got to go./I must go.
Nunca he estado en Londres.|I've never been to London.
Me duele la cabeza.|I have a headache./I've got a headache./My head hurts.
¿Qué tiempo hace?|What's the weather like?
Si tuviera más tiempo, viajaría más.|If I had more time, I would travel more.
Deberías descansar un poco.|You should rest a bit./You should rest a little./You should get some rest.
Estoy de acuerdo contigo.|I agree with you.
¿Te importa si abro la ventana?|Do you mind if I open the window?
Se me olvidó llamarte.|I forgot to call you.
Cuanto más practico, más fácil me resulta.|The more I practise, the easier it gets./The more I practice, the easier it gets./The more I practise, the easier it is./The more I practice, the easier it is.
La semana que viene empiezo un curso nuevo.|I'm starting a new course next week./I start a new course next week./I'm going to start a new course next week./Next week I'm starting a new course.
¿Has terminado ya?|Have you finished yet?/Are you done yet?/Have you already finished?
Me pongo nervioso cuando hablo en inglés.|I get nervous when I speak English./I get nervous when I speak in English.
Llegaré un poco tarde.|I'll be a bit late./I'll be a little late./I'll arrive a bit late.
¿Desde cuándo estudias inglés?|How long have you been studying English?/How long have you been learning English?
Ojalá pudiera hablar inglés con fluidez.|I wish I could speak English fluently.
No me di cuenta de que era tan tarde.|I didn't realise it was so late./I didn't realize it was so late.
Acabo de llegar a casa.|I've just got home./I just got home./I've just arrived home./I have just got home.
¿Me puedes ayudar con esto?|Can you help me with this?/Could you help me with this?
Está lloviendo a cántaros.|It's pouring./It's pouring down./It's raining cats and dogs./It's raining heavily.`;

  const TR_PL_EN = `
Jestem głodny.|I'm hungry.
Ile masz lat?|How old are you?
Dzisiaj jest zimno.|It's cold today./Today it's cold.
Lubię czytać przed snem.|I like reading before bed./I like to read before bed./I like reading before I go to sleep./I like to read before I go to sleep./I like reading before sleeping.
Mieszkam w Warszawie od trzech lat.|I've been living in Warsaw for three years./I've lived in Warsaw for three years.
Możesz powtórzyć?|Can you repeat that?/Could you repeat that?/Can you say that again?/Could you say that again?
Nie wiem, co powiedzieć.|I don't know what to say.
Szukam pracy.|I'm looking for a job./I'm looking for work.
Wczoraj byłem u lekarza.|I went to the doctor yesterday./Yesterday I went to the doctor./I was at the doctor's yesterday./I went to the doctor's yesterday.
Czym się zajmujesz?|What do you do?/What do you do for a living?
Muszę już iść.|I have to go now./I've got to go now./I must go now./I have to go./I've got to go.
Nigdy nie byłem w Londynie.|I've never been to London.
Boli mnie głowa.|I have a headache./I've got a headache./My head hurts.
Jaka jest pogoda?|What's the weather like?
Gdybym miał więcej czasu, więcej bym podróżował.|If I had more time, I would travel more.
Powinieneś trochę odpocząć.|You should rest a bit./You should rest a little./You should get some rest.
Zgadzam się z tobą.|I agree with you.
Czy mogę otworzyć okno?|Can I open the window?/Could I open the window?/May I open the window?
Zapomniałem do ciebie zadzwonić.|I forgot to call you.
Im więcej ćwiczę, tym łatwiej mi idzie.|The more I practise, the easier it gets./The more I practice, the easier it gets./The more I practise, the easier it is./The more I practice, the easier it is.
W przyszłym tygodniu zaczynam nowy kurs.|I'm starting a new course next week./I start a new course next week./I'm going to start a new course next week./Next week I'm starting a new course.
Skończyłeś już?|Have you finished yet?/Are you done yet?/Have you already finished?
Denerwuję się, kiedy mówię po angielsku.|I get nervous when I speak English./I get nervous when I speak in English.
Trochę się spóźnię.|I'll be a bit late./I'll be a little late.
Od kiedy uczysz się angielskiego?|How long have you been learning English?/How long have you been studying English?
Chciałbym mówić płynnie po angielsku.|I'd like to speak English fluently./I would like to speak fluent English./I'd like to speak fluent English.
Nie zauważyłem, że jest tak późno.|I didn't realise it was so late./I didn't realize it was so late./I didn't notice it was so late.
Właśnie wróciłem do domu.|I've just got home./I just got home./I've just come home./I've just got back home.
Pomożesz mi z tym?|Can you help me with this?/Could you help me with this?/Will you help me with this?
Leje jak z cebra.|It's pouring./It's pouring down./It's raining cats and dogs./It's raining heavily.`;

  const TR_EN_ES = `
I'm hungry.|Tengo hambre.
How old are you?|¿Cuántos años tienes?
It's cold today.|Hoy hace frío./Hace frío hoy.
I like reading before bed.|Me gusta leer antes de dormir./Me gusta leer antes de acostarme.
I've lived in Madrid for three years.|Llevo tres años viviendo en Madrid./Vivo en Madrid desde hace tres años./Hace tres años que vivo en Madrid.
Can you repeat that, please?|¿Puedes repetirlo, por favor?/¿Puede repetirlo, por favor?/¿Me lo repites, por favor?
I don't know what to say.|No sé qué decir.
I'm looking for a job.|Estoy buscando trabajo./Busco trabajo.
I went to the doctor yesterday.|Ayer fui al médico./Fui al médico ayer.
What do you do for a living?|¿A qué te dedicas?/¿En qué trabajas?
I have to go.|Tengo que irme./Me tengo que ir.
I've never been to Barcelona.|Nunca he estado en Barcelona./No he estado nunca en Barcelona.
I have a headache.|Me duele la cabeza./Tengo dolor de cabeza.
What's the weather like?|¿Qué tiempo hace?
If I had more time, I would travel more.|Si tuviera más tiempo, viajaría más./Si tuviese más tiempo, viajaría más.
You should rest a bit.|Deberías descansar un poco.
I agree with you.|Estoy de acuerdo contigo.
Do you mind if I open the window?|¿Te importa si abro la ventana?/¿Le importa si abro la ventana?
I forgot to call you.|Se me olvidó llamarte./Olvidé llamarte.
The more I practise, the easier it gets.|Cuanto más practico, más fácil me resulta./Cuanto más practico, más fácil es.
I'm starting a new course next week.|La semana que viene empiezo un curso nuevo./La próxima semana empiezo un curso nuevo./La semana que viene empiezo un nuevo curso./Empiezo un curso nuevo la semana que viene.
Have you finished yet?|¿Ya has terminado?/¿Has terminado ya?/¿Ya terminaste?
I get nervous when I speak Spanish.|Me pongo nervioso cuando hablo español./Me pongo nerviosa cuando hablo español./Me pongo nervioso cuando hablo en español./Me pongo nerviosa cuando hablo en español.
I'll be a bit late.|Llegaré un poco tarde./Voy a llegar un poco tarde.
How long have you been studying Spanish?|¿Cuánto tiempo llevas estudiando español?/¿Desde cuándo estudias español?
I wish I could speak Spanish fluently.|Ojalá pudiera hablar español con fluidez./Ojalá pudiera hablar español con soltura.
I didn't realise it was so late.|No me di cuenta de que era tan tarde.
I've just got home.|Acabo de llegar a casa.
Can you help me with this?|¿Me puedes ayudar con esto?/¿Puedes ayudarme con esto?/¿Me ayudas con esto?
It's raining cats and dogs.|Está lloviendo a cántaros./Llueve a cántaros.`;

  const TR_PL_ES = `
Jestem głodny.|Tengo hambre.
Ile masz lat?|¿Cuántos años tienes?
Dzisiaj jest zimno.|Hoy hace frío./Hace frío hoy.
Lubię czytać przed snem.|Me gusta leer antes de dormir./Me gusta leer antes de acostarme.
Mieszkam w Madrycie od trzech lat.|Llevo tres años viviendo en Madrid./Vivo en Madrid desde hace tres años./Hace tres años que vivo en Madrid.
Możesz powtórzyć?|¿Puedes repetirlo?/¿Me lo repites?/¿Puedes repetir?
Nie wiem, co powiedzieć.|No sé qué decir.
Szukam pracy.|Busco trabajo./Estoy buscando trabajo.
Wczoraj byłem u lekarza.|Ayer fui al médico./Ayer estuve en el médico./Fui al médico ayer.
Czym się zajmujesz?|¿A qué te dedicas?/¿En qué trabajas?
Muszę już iść.|Tengo que irme ya./Ya me tengo que ir./Me tengo que ir ya./Tengo que irme.
Nigdy nie byłem w Barcelonie.|Nunca he estado en Barcelona./No he estado nunca en Barcelona.
Boli mnie głowa.|Me duele la cabeza.
Jaka jest pogoda?|¿Qué tiempo hace?
Gdybym miał więcej czasu, więcej bym podróżował.|Si tuviera más tiempo, viajaría más./Si tuviese más tiempo, viajaría más.
Powinieneś trochę odpocząć.|Deberías descansar un poco.
Zgadzam się z tobą.|Estoy de acuerdo contigo.
Czy mogę otworzyć okno?|¿Puedo abrir la ventana?
Zapomniałem do ciebie zadzwonić.|Se me olvidó llamarte./Olvidé llamarte.
Im więcej ćwiczę, tym łatwiej mi idzie.|Cuanto más practico, más fácil me resulta./Cuanto más practico, más fácil es.
W przyszłym tygodniu zaczynam nowy kurs.|La semana que viene empiezo un curso nuevo./La próxima semana empiezo un curso nuevo./La semana que viene empiezo un nuevo curso./Empiezo un curso nuevo la semana que viene.
Skończyłeś już?|¿Ya has terminado?/¿Has terminado ya?/¿Ya terminaste?
Denerwuję się, kiedy mówię po hiszpańsku.|Me pongo nervioso cuando hablo español./Me pongo nerviosa cuando hablo español./Me pongo nervioso cuando hablo en español./Me pongo nerviosa cuando hablo en español.
Trochę się spóźnię.|Llegaré un poco tarde./Voy a llegar un poco tarde.
Od kiedy uczysz się hiszpańskiego?|¿Desde cuándo estudias español?/¿Cuánto tiempo llevas estudiando español?
Chciałbym mówić płynnie po hiszpańsku.|Me gustaría hablar español con fluidez./Quisiera hablar español con fluidez./Me gustaría hablar español con soltura.
Nie zauważyłem, że jest tak późno.|No me di cuenta de que era tan tarde.
Właśnie wróciłem do domu.|Acabo de llegar a casa./Acabo de volver a casa.
Pomożesz mi z tym?|¿Me ayudas con esto?/¿Me puedes ayudar con esto?/¿Puedes ayudarme con esto?
Leje jak z cebra.|Está lloviendo a cántaros./Llueve a cántaros.`;

  // ---- Short rule notes, shown after an answer, in the student's language ---
  const NOTES = {
    'time-in':   { es: 'in + meses, años, estaciones y partes del día (in the morning).', pl: 'in + miesiące, lata, pory roku i części dnia (in the morning).', en: 'in + months, years, seasons and parts of the day (in the morning).' },
    'time-on':   { es: 'on + días y fechas (on Monday, on the 3rd of May).', pl: 'on + dni i daty (on Monday, on the 3rd of May).', en: 'on + days and dates (on Monday, on the 3rd of May).' },
    'time-at':   { es: 'at + horas y momentos concretos (at five, at night, at Christmas).', pl: 'at + godziny i konkretne momenty (at five, at night, at Christmas).', en: 'at + clock times and fixed moments (at five, at night, at Christmas).' },
    'place-in':  { es: 'in = dentro de un espacio: una habitación, una ciudad, un país.', pl: 'in = wewnątrz: pokój, miasto, kraj.', en: 'in = inside a space: a room, a city, a country.' },
    'place-on':  { es: 'on = sobre una superficie, y también on TV, on holiday, on the internet.', pl: 'on = na powierzchni, a także on TV, on holiday, on the internet.', en: 'on = on a surface, and also on TV, on holiday, on the internet.' },
    'place-at':  { es: 'at = un punto o lugar concreto: at the bus stop, at the airport, at work.', pl: 'at = konkretny punkt lub miejsce: at the bus stop, at the airport, at work.', en: 'at = a point or specific place: at the bus stop, at the airport, at work.' },
    'dependent': { es: 'Esta preposición va unida a la palabra anterior: apréndelas juntas.', pl: 'Ten przyimek łączy się z poprzednim słowem: ucz się ich razem.', en: 'This preposition goes with the word before it: learn them as a pair.' },
    'since-for': { es: 'since + el momento de inicio (since 2019); for + la duración (for six years).', pl: 'since + moment początku (since 2019); for + czas trwania (for six years).', en: 'since + the starting point (since 2019); for + the length of time (for six years).' },
    'transport': { es: 'by + medio de transporte (by car, by bus), pero on foot. Get on/off un bus o tren.', pl: 'by + środek transportu (by car, by bus), ale on foot. Get on/off autobus lub pociąg.', en: 'by + means of transport (by car, by bus), but on foot. Get on/off a bus or train.' },
    'por-cause':     { es: 'por = causa o motivo (gracias por, por el tráfico).', pl: 'por = przyczyna lub powód (gracias por, por el tráfico).', en: 'por = cause or reason (gracias por, por el tráfico).' },
    'por-through':   { es: 'por = a través de, por dentro de un lugar.', pl: 'por = przez, po jakimś miejscu.', en: 'por = through, around a place.' },
    'por-exchange':  { es: 'por = intercambio o precio.', pl: 'por = wymiana lub cena.', en: 'por = exchange or price.' },
    'por-means':     { es: 'por = medio: por teléfono, por email.', pl: 'por = sposób: por teléfono, por email.', en: 'por = means: por teléfono, por email.' },
    'por-time':      { es: 'por la mañana / tarde / noche (en Latinoamérica también "en la tarde").', pl: 'por la mañana / tarde / noche (w Ameryce Łacińskiej też "en la tarde").', en: 'por la mañana / tarde / noche (in Latin America also "en la tarde").' },
    'para-recipient':{ es: 'para = destinatario: para ti.', pl: 'para = odbiorca: para ti.', en: 'para = recipient: para ti.' },
    'para-purpose':  { es: 'para = finalidad: para + infinitivo.', pl: 'para = cel: para + bezokolicznik.', en: 'para = purpose: para + infinitive.' },
    'para-deadline': { es: 'para = fecha límite.', pl: 'para = termin, do kiedy.', en: 'para = deadline.' },
    'para-opinion':  { es: 'para mí = en mi opinión.', pl: 'para mí = moim zdaniem.', en: 'para mí = in my opinion.' },
    'a-direction':   { es: 'a = dirección con verbos de movimiento (ir a, llegar a).', pl: 'a = kierunek przy czasownikach ruchu (ir a, llegar a).', en: 'a = direction with verbs of movement (ir a, llegar a).' },
    'a-time':        { es: 'a + la hora: a las cinco.', pl: 'a + godzina: a las cinco.', en: 'a + clock time: a las cinco.' },
    'a-personal':    { es: '"a personal": delante de una persona que es objeto directo.', pl: '"a personal": przed osobą, która jest dopełnieniem.', en: 'Personal "a": before a person who is the direct object.' },
    'en-place':      { es: 'en = lugar donde estás (estar en casa, en la oficina).', pl: 'en = miejsce, w którym jesteś (estar en casa, en la oficina).', en: 'en = where you are (estar en casa, en la oficina).' },
    'en-transport':  { es: 'en + transporte: en tren, en coche (pero a pie).', pl: 'en + transport: en tren, en coche (ale a pie).', en: 'en + transport: en tren, en coche (but a pie).' },
    'de-origin':     { es: 'de = origen, posesión o punto de partida (de lunes a viernes).', pl: 'de = pochodzenie, przynależność lub początek (de lunes a viernes).', en: 'de = origin, possession or starting point (de lunes a viernes).' },
    'con':           { es: 'con = compañía o ingrediente.', pl: 'con = towarzystwo lub składnik.', en: 'con = company or ingredient.' },
    'desde':         { es: 'desde hace + duración = since/for: "vivo aquí desde hace tres años".', pl: 'desde hace + czas = od: "vivo aquí desde hace tres años".', en: 'desde hace + length of time: "vivo aquí desde hace tres años".' },
    'verb-prep':     { es: 'Este verbo pide esta preposición: apréndelos juntos.', pl: 'Ten czasownik wymaga tego przyimka: ucz się ich razem.', en: 'This verb takes this preposition: learn them as a pair.' }
  };

  // ---- Parsing --------------------------------------------------------------
  const lines = s => s.trim().split('\n').map(l => l.trim()).filter(Boolean);
  const alts = s => s.split('/').map(x => x.trim()).filter(Boolean);
  const pad = n => String(n).padStart(3, '0');

  const enVerbs = lines(EN_VERBS).map(l => {
    const [base, past, pp, es, pl] = l.split('|');
    return { id: 'en-v-' + base, base, past: alts(past), pp: alts(pp), meaning: { es, pl } };
  });

  const preps = (src, prefix) => lines(src).map((l, i) => {
    const [rule, sentence, ans] = l.split('|');
    return { id: prefix + pad(i + 1), rule, sentence, answers: alts(ans) };
  });

  const translations = (src, prefix) => lines(src).map((l, i) => {
    const [prompt, ans] = l.split('|');
    return { id: prefix + pad(i + 1), prompt, answers: alts(ans) };
  });

  const esVerbs = [];
  lines(ES_IRREGULAR).forEach(l => {
    const [inf, en, pl, pres, pret] = l.split('|');
    esVerbs.push({ inf, meaning: { en, pl }, pres: pres.split(','), pret: pret.split(','), irregular: true });
  });
  lines(ES_REGULAR).forEach(l => {
    const [inf, en, pl] = l.split('|');
    const stem = inf.slice(0, -2), e = ES_ENDINGS[inf.slice(-2)];
    esVerbs.push({ inf, meaning: { en, pl }, pres: e.pres.map(x => stem + x), pret: e.pret.map(x => stem + x), irregular: false });
  });

  const esConj = tense => {
    const out = [];
    esVerbs.forEach(v => (tense === 'pres' ? v.pres : v.pret).forEach((form, p) => {
      out.push({ id: `es-c-${v.inf}-${tense}-${p + 1}`, inf: v.inf, meaning: v.meaning, person: ES_PERSONS[p], tense, answers: [form], irregular: v.irregular });
    }));
    return out;
  };

  return {
    notes: NOTES,
    en: {
      verbs: enVerbs,
      prepositions: preps(EN_PREPS, 'en-p-'),
      translation: { es: translations(TR_ES_EN, 'en-t-es-'), pl: translations(TR_PL_EN, 'en-t-pl-') }
    },
    es: {
      verbsPresent: esConj('pres'),
      verbsPast: esConj('pret'),
      prepositions: preps(ES_PREPS, 'es-p-'),
      translation: { en: translations(TR_EN_ES, 'es-t-en-'), pl: translations(TR_PL_ES, 'es-t-pl-') }
    }
  };
})();
