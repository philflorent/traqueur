#!/bin/bash
#	P.Florent 09/08/2024 - https://pgphil.ovh - Traqueur v8.00.01 pour PostgreSQL 12 => 17
# Copyright (c) 2017-2024, PHILIPPE FLORENT
# Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.
# IN NO EVENT SHALL PHILIPPE FLORENT BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF PHILIPPE FLORENT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# PHILIPPE FLORENT SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND PHILIPPE FLORENT HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

umask 077

declare version="8.00.01"
declare min_pg_version="12"
declare max_pg_version="17"
declare OS=`uname`

if [[ -z ${TRAQUEUR_W+x} ]]; then
	declare TRAQUEUR_W=/tmp
fi

# DEBUT USAGE ERROR  WARNING INFORMATION INTERACTION MESSAGES

if [[ $LANG == fr* ]] || [[ $LANG == FR* ]] || [[ $LANG == Fr* ]]; then

	usage_001="traqueur ${version} - https://pgphil.ovh - outil de diagnostic performance pour PostgreSQL version ${min_pg_version} => ${max_pg_version}\n"
	usage_001+="usage: traqueur.sh [-h] [ -v niveau ] [ -t 1|2|3|4|5 ] [-c parametres de connexion] [ -q role ] [ -r ] [ -m fenetre ] [ -z ] [ -s delai ] [ -b L|U|F|H ] [ -e L|U ] [ -j ] [-d duree ] [ -w pids ] [ -n ] [ -y ] [ -f ] [ -g \"commentaire\" ] [ -p ] [ -i profondeur ] [ -o colonnes ]  [ -k iterations ] [ -l ] [ -a t|x|tx ] [ -C L|U ] [ -D ] [ -F informations ] [ -A role ] [ -R role ] [ -S schema ] [ -N ] [ -L ] [ -H dossier ] [ -K ]\n"
  	usage_001+=" -h              : affiche ce message et sort\n" 
	usage_001+=" -v niveau       : niveau de verbosite du script apres la lecture des arguments, 0 aucun message, 1 erreurs, 2 erreurs/warnings, 3 erreurs/warnings/informations (par defaut 3)\n"
	usage_001+=" -t 1|2|3|4|5    : effectue un test de performance et sort. Entre 1 et 4, test CPU/RAM (calcul d'un grand nombre premier avec l'argument 1, calcul de decimales de pi avec les argument 2, 3 et 4). 5 effectue un test de latence I/O. L'execution du traqueur doit toujours etre faite sur le serveur postgresql. Les tests 1, 2, 3, 4 necessitent gcc. Le test 1 utilise 600M dans \$TRAQUEUR_W (/tmp par defaut si la variable \$TRAQUEUR_W n'est pas positionnee). Le test 5 necessite bonnie++ v1.97+ et utilise 1Go dans \$PGDATA/base (/var/lib/postgresql/13/main/base par defaut si la variable \$PGDATA n'est pas positionnee) et consomme beaucoup de ressources I/O \n"
	usage_001+=" -c parametres   : parametres de connexion passes au programme psql\n"			
	usage_001+=" -q role         : cree un role permettant d'eviter les connexions en tant que superuser en interactif (une premiere utilisation du traqueur avec un superuser est toujours necessaire pour creer les extensions dans la base de travail) et sort. \n"			
	usage_001+=" -r              : produit un rapport en interrogeant les donnees obtenues en mode batch et sort, l'option -p ajoute les infos sur les temps CPU pendant la periode, l'option -l ajoute les informations concernant la latence I/O avec PostgreSQL 16 et versions superieures. \n"
	usage_001+=" -m fenetre      : supprime en base les donnees collectees en mode batch en fonction d'une fenetre de conservation exprimee en jours (fenetre est un entier, une fenetre de 0 tronque les tables) et sort. Lorsque les donnees sont collectes avec -b F et donc stockees dans un repository distant, le traqueur avec l'option -m doit etre directement execute sur le cluster du repository\n"
	usage_001+=" -z              : supprime en base le schema du traqueur designe par \$TRAQUEUR_LOCAL_SCHEMA (par defaut traqueur)\n"
	usage_001+=" -s delai        : delai minimal en centiemes de secondes entre 2 interrogations de pg_stat_activity lors de la collecte (par defaut 10, minimum 0). Avec -p le delai effectif sera toujours > 0.1s. -s 0 supprime les temps de sommeil du script : cette option ne peut pas etre combinee avec l'option -b et la duree reelle du script peut varier enormement\n"
	usage_001+=" -a t|x|tx       : avec l'argument t, active le chronometrage par requete de psql pendant la phase de collecte et la presentation des resultats. Avec l'argument x, active l'affichage psql etendu, prise en compte lors de l'affichage des resultats. L'argument tx combine les 2 options.\n"
	usage_001+=" -b L|U|F|H      : mode batch, multiplie par 100 le delai fixe par -s. Au lieu d'etre stockees dans des tables temporaires afin de produire un rapport immediat, les donnees collectees sont conservees en base dans des tables non journalisees (unlogged) avec l'argument U, journalisees (logged) avec l'argument L, distantes (foreign) avec l'argument F. -b F necessite un repository cree avec l'option -C dans la meme version majeure de PostgreSQL. Avec l'argument H, un fichier plat est utilise au lieu de tables et les options -n, -f, -g, -p ne sont pas prises en compte. -b H peut etre utilise sur des clusters en lecture seule (hot standby). Les donnees de performance concernant les I/O sont automatiquement incluses toutes les 10 iterations si track_io_timing=on avec PostgreSQL 16 et versions superieures. \n"
	usage_001+=" -e L|U          : utilisee avec l'argument L, l'option -e passe les tables creees par l'option -b en mode logged, et sort. Avec l'argument U, l'option -e passe les tables en mode unlogged, et sort. Cette option provoque une erreur sur les tables distantes creees avec  l'option -b F\n"
	usage_001+=" -j              : tire parti du partitionnement natif des tables en mode batch (option -b). L'option -j peut egalement etre utilisee en combinaison avec l'option -m pour realiser des suppressions de partitions au lieu de suppressions de lignes et avec l'option -C pour utiliser le partionnement dans un repository du traqueur.\n"
	usage_001+=" -d duree        : valeur entiere, duree approximative de la partie analyse du script en secondes (jours en mode batch) (par defaut 5, minimum 0). -d 0 realise une seule interrogation de pg_stat_activity et pg_locks. avec -s 0, la duree peut etre tres eloignee de la duree prevue\n"
	usage_001+=" -w pids         : filtrage de la collecte sur une liste de pids separes par , ou toute requete retournant des pids (exemple \"7232,4281\" ou \"select pid from pg_stat_activity where application_name = 'appli'\", par defaut \"select pid from pg_stat_activity where coalesce(wait_event_type,'') not in ('Timeout', 'Activity')\"\n"
	usage_001+=" -n              : normalise les requetes lors de la collecte, remplacement des valeurs numeriques par 0, des valeurs chaines par '' et des listes par (...)\n"
	usage_001+=" -y              : lors de la collecte, renseigne la colonne de type jsonb application_info (cles : program, module, action, client_info, sofar, totalwork) depuis la colonne application_name de pg_stat_activity. Le format d'application_name doit etre programme,module,action,informations_clientes,travail_effectue,travail_restant.\n" 
	usage_001+=" -f              : lors de la collecte, renseigne la colonne de type tsvector dquery permettant d'appliquer des filtres texte sur les donnees de query lors de la production de rapports, option non recommandee sauf cas tres particulier\n" 
	usage_001+=" -g commentaire  : en mode batch (option -b), collecte d'informations generales et de statistiques sur le cluster (version de PostgreSQL, taille etc.) pouvant etre utilisees en reporting. Le commentaire est utilise pour renseigner une colonne dediee. L'option -g cree par ailleurs une table utilisable pour renseigner manuellement les resultats de benchmarks\n"
	usage_001+=" -u              : en mode batch (option -b), collecte d'informations detaillees sur les bloqueurs et transactions preparees\n"		
	usage_001+=" -p              : collecte d'informations sur l'activite CPU et la consommation memoire, necessite le module python psutil (version >= 4 pour les infos memoire)\n"
	usage_001+=" -i profondeur   : niveau de profondeur pour l'analyse recursive des bloqueurs finaux (par defaut 2)\n"
	usage_001+=" -o colonnes     : choix de colonnes lors de l'affichage des resultats parmi celles de pg_stat_activity separees par \",\" avec en plus \"blockers\" (liste de processus bloquants finaux, 0 designant une ou plusieurs transactions preparees), \"to_hex(iquery)\" (valeur de hachage de la requete), \"tquery\" (requete normalisee), \"to_hex(itquery)\" (valeur de hachage de la requete normalisee), application_info (informations clientes). Ce choix se substitue au choix par defaut qui peut par ailleurs etre demande explicitement avec -o \"defaut\". Utiliser -o avec \"\" ou avec une constante permet de considerer toutes les sessions actives sans agregation. L'option -o peut etre renseignee plusieurs fois afin d'agreger de differentes manieres les resultats de la collecte\n"	
	usage_001+=" -k iterations   : arrete prematurement la collecte si elle ne ramene aucune information \"iterations\" fois consecutivement (minimum 1). Cette option n'est pas effective sur un cluster en lecture seule (-b H).\n"	
	usage_001+=" -l              : en mode interactif, affiche les informations de latence I/O  (en millisecondes) et les evictions du cache avec PostgreSQL 16 et versions superieures \n"	
	usage_001+=" -C L|U          : cree un repository, un schema pouvant etre utilise pour stocker les donnees collectes en mode batch (les tables sont logged avec l'argument L, unlogged avec l'argument U), cree un utilisateur avec les privileges select et insert et un utilisateur avec les privileges select sur les tables du repository puis sort.\n"	
	usage_001+=" -D              : supprime le schema du repository, supprime les utilisateur crees par l'option -C et sort\n"
	usage_001+=" -F informations : cette option peut etre combinee avec l'option -b F option afin de fournir les informations de connexion vers un repository (par defaut \"host 'traqueur', dbname 'traqueur', port '5432'\")\n"
	usage_001+=" -A role         : cette option peut etre combinee avec les options -C, -D , -b F et -F afin d'indiquer un role ayant les privileges insert et select sur les tables du repository (par defaut traqueur_agent)\n"
	usage_001+=" -R role         : cette option peut etre combinee avec les options -C et -D  afin d'indiquer un role ayant les privileges select sur les tables du repository (par defaut traqueur_dashboard)\n"
	usage_001+=" -S schema       : cette option peut etre combinee avec les options -C, -D , -b F et -F afin d'indiquer le schema du repository (par defaut traqueur)\n"	
	usage_001+=" -N              : cette option peut etre combinee avec l'option -b F afin de ne pas renseigner de mot de passe dans la correspondance entre l'utilisateur PostgreSQL executant le traqueur et l'utilisateur PostgreSQL du repository\n"	
	usage_001+=" -L              : charge un fichier plat produit sur une hot standby dans un repository cree par l'option -C, supprime du fichier les informations chargees et sort. Le cluster sur lequel le fichier a ete produit et le cluster cible doivent etre dans la meme version majeure de PostgreSQL\n"	
	usage_001+=" -H dossier      : cette option peut etre combinee avec l'option -b H, -r H, -L pour indiquer le dossier du fichiers plat traqueur_sessions_actives.txt (dossier par defaut $PGDATA/traqueur)\n"	
	usage_001+=" -K              : supprime les fichiers de travail traqueur.pid obsoletes et stoppe les processus du traqueur tournant en mode batch, cette option peut etre combinee avec l'option -c\n"
	usage_001+=" priorite        : l'ordre de priorite des options speciales, entrainant une sortie du script sans collecte d'informations sur l'activite de postgresql, est -t -K -q -L -C -D -r -e -z\n"
	
	error_001_psql="ERREUR, commande psql inaccessible, verifiez \$PATH"
	error_002_options="ERREUR, options specifiees incorrectes"
	error_003_bonnie="ERREUR, commande bonnie++ inaccessible"
	error_004_duree="ERREUR, la duree saisie apres -d doit etre un entier > 0"
	error_005_fenetre="ERREUR, la fenetre de conservation en jours saisie apres -m doit etre un entier >= 0"
	error_006_verbosite="ERREUR, la verbosite saisie apres -v doit etre un entier compris entre 0 et 3"
	error_007_sommeil="ERREUR, le delai en centiemes de seconde entre 2 interrogations de pg_stat_activity doit etre un entier >= 0"
	error_008_espace="ERREUR, espace insuffisant dans "
	error_009_espace="ERREUR, espace necessaire : "
	error_010_espace="ERREUR, liberer de l'espace ou designer un dossier different en affectant la variable "
	error_011_gcc="ERREUR, commande gcc inaccessible"
	error_012_echec="ECHEC"
	error_013_choix_mode_journalisation="ERREUR, les options -e -b et -C doivent etre suivies de L (logged) ou U (unlogged). L'option -b accepte egalement F (foreign)"
	error_014_profondeur_analyse_verrous="ERREUR, le niveau de recursivite dans l'analyse de verrous saisi apres -i doit etre un entier >= 0"
	error_015_postgresql_version="ERREUR, fonctionnalite indisponible avec cette version de PostgreSQL "
	error_016_bellard_bonnie="ERREUR, l'argument saisi apres -t doit etre 1, 2, 3, 4 ou 5"
	error_017_rapport="ERREUR, l'argument saisi apres -r doit etre D, L ou H"
	error_018_stop_collection="ERREUR, le nombre d'iterations infructueuses saisi apres -k doit etre un entier >= 1"
	error_019_affichage="ERREUR, l'argument saisi apres -a doit etre t, x ou tx"
	error_020_plpython="ERREUR, aucune extension plpython disponible"
	error_021_track_io_timing="ERREUR, track_io_timing = on necessaire pour obtenir la latence I/O avec l'argument -l" 
	
	warning_001_bonnie="ATTENTION, commande bonnie++ inaccessible, ajout de /usr/sbin au PATH"
	warning_002_espace="ATTENTION, verification de l'espace libre impossible dans "
	warning_003_postgres_version="ATTENTION, version de PostgreSQL non supportee"
	warning_004_table_introuvable="ATTENTION, table introuvable "
	warning_005_pas_de_base_traqueur="ATTENTION, aucune base dediee detectee et aucun parametre de connexion fourni, tentative de connexion sans parametres"
	warning_006_pas_connecte_base_traqueur="ATTENTION, la base de travail n'est pas appelee "
	warning_007_partitionnement_distant="ATTENTION, l'option -j est ignoree, le partitionnement doit etre active lors de la creation du repository par l'option -C"
	warning_008_utilisateur_connecte_schema="ATTENTION, l'utilisateur de connexion et le schema de travail ont des noms differents :"
	warning_009_bloom_unavailable="ATTENTION, l'extension bloom n'est pas disponible"
	
	info_000_version="traqueur ${version} - https://pgphil.ovh - outil de diagnostic performance pour PostgreSQL ${min_pg_version} => ${max_pg_version}"
	info_001_preparation_traque="INFORMATION, preparation de la collecte ..."
	info_002_execution_traque="INFORMATION, execution de la collecte et presentation des resultats ..."
	info_003_bonnie="INFORMATION, test latence avec bonnie++ ..."
	info_004_base_traqueur="INFORMATION, pas de base de connexion indiquee, utilisation de la base dediee detectee ... "
	info_006_rapport="INFORMATION, production d'un rapport depuis les informations collectees par le traqueur en mode batch ... "
	info_007_menage="INFORMATION, menage dans les tables utilisees par le traqueur ... "
	info_008_bellard="INFORMATION, test CPU ..."
	info_009_change_journalisation="INFORMATION, modification du mode de journalisation des tables du traqueur ... "
	info_010_execution_traque_batch="INFORMATION, execution de la collecte ..."	
	info_011_table_introuvable="INFORMATION, table introuvable "
	info_012_suppression_lignes="INFORMATION, menage OK, % lignes supprimees"	
	info_014_postgres_version="INFORMATION, version de PostgreSQL detectee : "
	info_015_connecte_base_traqueur="INFORMATION, connecte a la base "	
	info_020_creation_repository="INFORMATION, creation du repository ... "
	info_021_destruction_repository="INFORMATION, destruction du repository ... "
	info_022_creation_user_monitoring_interactif="INFORMATION, creation de l'utilisateur interactif de monitoring ... "
	info_023_score_cpu="INFORMATION, score CPU (s) ... "
	info_024_latence="INFORMATION, latence I/O ... "
	info_025_chargement_fichiers_plats="INFORMATION, chargement des fichiers du traqueur ... "
	info_026_stop_traqueur="INFORMATION, arret du traqueur ... "

	interactive_001_debut_rapport="Variable TRAQUEUR_RAPPORT_DEBUT non renseignee, indiquez la borne de temps inferieure, par defaut : current_timestamp - interval '15 minutes'"
	interactive_002_fin_rapport="Variable TRAQUEUR_RAPPORT_FIN non renseignee, indiquez la borne de temps superieure, par defaut : current_timestamp"
	interactive_003_top_n_rapport="Variable TRAQUEUR_RAPPORT_TOP_N non renseignee, indiquez le nombre d'elements pour les tops evenements et requetes, par defaut : 5"
	interactive_004_filtre_rapport="Variable TRAQUEUR_RAPPORT_FILTRE non renseignee, indiquez les options de filtrage pour les tops requetes et applications, par defaut : application_name <> 'traqueur' and backend_type <> 'autovacuum worker' and backend_type <> 'walsender'"
	interactive_005_format_rapport="Variable TRAQUEUR_RAPPORT_FORMAT non renseignee, indiquez le format du rapport (aligned pour obtenir du texte ou html), par defaut : aligned"
	interactive_006_nom_rapport="Variable TRAQUEUR_RAPPORT_NOM non renseignee, indiquez le chemin et le nom du fichier du rapport, par defaut : ${TRAQUEUR_W}/rapport_traqueur_$$.txt (ou ${TRAQUEUR_W}/rapport_traqueur_$$.htm si le format est html)"
	
	report_000_titre="RAPPORT DU TRAQUEUR"
	report_001_serveur="Nom du serveur"
	report_002_borne_inferieure="Borne inferieure"
	report_003_borne_superieure="Borne superieure"
	report_004_infos_systeme="Infos Systeme"
	report_005_charge_CPU="Charge CPU moyennne globale (hors traqueur)"
	report_006_temps_CPU_user="Temps_CPU_User_en_s"
	report_007_temps_CPU_systeme="Temps_CPU_Systeme_en_s"
	report_008_temps_CPU_idle="Temps_CPU_Idle_en_s"
	report_009_temps_io="Temps_IO_en_s"
	report_010_evenements="Evenements"
	report_011_requetes="Requetes"
	report_012_type_evenement="Type evenement"
	report_013_nombre_de_detections="Nombre de detections"
	report_014_base_de_donnees="Base de donnees"
	report_015_utilisateur="Utilisateur"
	report_016_identifiant_requete="Identifiant requete"
	report_017_requete="Requete"
	report_018_application="Application"
	report_019_nombre_executions_distinctes="Nombre d'executions distinctes"
	report_020_pourcentage_moyen_non_CPU="Pourcentage moyen d'activite non CPU"
	report_021_max_conso_memoire="Consommation maximale de memoire"
	report_022_max_conso_swap="Consommation maximale de swap"
	report_023_elapsed="Temps horloge"
	report_024_dbtime="Temps base de donnees"
	report_025_avg_active_sessions="Nombre moyen de sessions actives"
	report_026_nombre_detections_nonparalleles="Nombre de detections (hors parallelisme)"
	report_027_latence="Latence I/O (en millisecondes) et evictions du cache"	
	report_028_latence_lectures="Latence lectures"
	report_029_latence_ecritures="Latence ecritures"
	report_030_latence_ecritures_permanentes="Latence ecritures permanentes"	
	report_031_latence_extensions_fichiers="Latence extensions fichiers"
	report_032_latence_fsyncs="Latence fsyncs"	
	report_033_evictions="Evictions"	
	report_034_total_memory="Memoire physique totale (en excluant le swap, en Mo)"
	report_035_min_memory_occupation="Occupation minimale de la memoire (pourcentage)"
	report_036_avg_memory_occupation="Occupation moyenne de la memoire (pourcentage)"
	report_037_max_memory_occupation="Occupation maximale de la memoire (pourcentage)"
	report_038_total_swap="Swap alloue (en Mo)"
	report_039_min_swap_occupation="Occupation minimale du swap (pourcentage)"
	report_040_avg_swap_occupation="Occupation moyenne du swap (pourcentage)"
	report_041_max_swap_occupation="Occupation maximale du swap (pourcentage)"
	report_042_swapped_memory="Memoire swappee"
else

	usage_001="traqueur ${version} - https://pgphil.ovh - performance tool for PostgreSQL version ${min_pg_version} => ${max_pg_version}\n"
	usage_001+="usage: traqueur.sh [-h] [ -v level ] [ -t 1|2|3|4|5 ] [-c connection parameters]  [ -q role ] [ -r ] [ -m window ] [ -z ] [ -s interval ] [ -b L|U|F|H ] [ -e L|U ] [ -j ] [-d duration ] [ -w pids ] [ -n ] [ -y ] [ -f ] [ -g \"comment\" ] [ -p ] [ -i depth ] [ -o columns ] [ -k iterations ] [ -a t|x|tx ] [ -C L|U ] [ -D ] [ -F informations ] [ -A role ] [ -R role ] [ -S schema ] [ -N ] [ -L ] [ -H folder ] [ -K ]\n"
	usage_001+=" -h              : prints this message and exits\n" 
	usage_001+=" -v level        : verbosity level, 0 no messages, 1 errors, 2 errors/warnings, 3 errors/warnings/informations (default 3)\n"	
	usage_001+=" -t 1|2|3|4|5    : runs a performance test and exits. Between 1 and 4, CPU/RAM test (prime number calculation with argument 1,  pi number calculation with argument 2, 3 and 4). 5 executes a latency I/O test. Traqueur must be executed from postgresql cluster host. Tests 1, 2, 3, 4 require gcc. Test 1 uses 600M in \$TRAQUEUR_W (/tmp by default if variable \$TRAQUEUR_W ist not set). Test 5 requires bonnie++ v1.97+ and used 1Gb in \$PGDATA/base (/var/lib/postgresql/11/main/base by default if variable \$PGDATA is not set) and a lot of I/O resources\n"
	usage_001+=" -c parameters   : connection parameters for psql\n"	
	usage_001+=" -q role         : creates a role that can be used to avoid superuser connections in interactive mode (a first execution of the traqueur as a superuser is always necessary to create extensions in traqueur database) and exits.\n"
	usage_001+=" -r              : creates a report based on data collected in batch mode and exits, -p option adds information about CPU times, -l option adds I/O latency  information with PostgreSQL 16 and superior versions.\n"
	usage_001+=" -m range        : deletes data collected in batch mode based on a range expressed in days (range is an integer, a range of 0 truncates the tables) and exits. If -b F was used to collect data, you have to execute traqueur vith -m option directly on the repository cluster\n"	
	usage_001+=" -z              : drops traqueur schema \$TRAQUEUR_LOCAL_SCHEMA (default traqueur)\n"	
	usage_001+=" -s interval     : minimum interval in hundredths of a second between 2 queries of pg_stat_activity (by default 10, minimum 1). With -p the effective interval will always be > 0.1s. -s 0 suppresses sleep times : it cannot be combined with -b option and real duration of the script can be very variable\n"
	usage_001+=" -a t|x|tx       : with t argument,  turns on psql timing. With argument x, turns on extended psql display. Argument tx combine this options.\n"
	usage_001+=" -b L|U|F|H      : batch mode, multiplies by 100 the interval set with -s. Data are stored in permanent tables instead of temporary tables, tables are unlogged with U argument, logged with L argument, foreign with F argument. -b F option requires a repository created with -C option in the same major version of PostgreSQL. With H argument, a flat file is used instead of tables and -n, -f, -g, -p options are ignored. -b H can be used on read-only clusters (hot standby). I/O performance data are automatically included every 10 iterations if track_io_timing=on with PostgreSQL 16 and superior versions. \n"
	usage_001+=" -e L|U          : option -e can be used to alter tables created in batch mode. Tables can be altered to unlogged with U argument or to logged with L argument. This option does not work with foreign tables created by -b F option\n"
	usage_001+=" -j              : partitions tables than can benefit from this feature in batch mode (-b option). -j option can also be combined with -m option to drop partitions instead of suppressing lines and with -C option to use partitioning in a traqueur repository. \n"
	usage_001+=" -d duration     : integer value, approximate traqueur execution duration in seconds (days en mode batch) (by defaut 5, minimum 0). with -d 0 pg_stat_activity and pg_locks are queried only once. with -s 0 real duration can be very different from the expected duration\n"
	usage_001+=" -w pids         : filters collected data using a list of pids separated by , or any query returning a list of pids (e.g \"7232,4281\" or \"select pid from pg_stat_activity where application_name = 'appli'\", by default \"select pid from pg_stat_activity where coalesce(wait_event_type,'') not in ('Timeout', 'Activity')\"\n"		 
	usage_001+=" -n              : normalizes queries, replacing numeric values by 0, string values by '' and lists by (...)\n"
	usage_001+=" -y              : fills an application_info column of jsonb type (keys : program, module, action, client_info, sofar, totalwork) based on application_name column of pg_stat_activity. application_name format must be program,module,action,client_information,sofar,totalwork.\n" 
	usage_001+=" -f              : fills a dquery column of tsvector type based on query column of pg_stat_activity\n"
	usage_001+=" -g comment      : in batch mode (-b option), collects general informations and statistics on the cluster (PostgreSQL version, size etc.) that can be used by reporting tools. Comment is used to fill a dedicated column. -g also creates a table than can be manually filled with benchmark results\n"
	usage_001+=" -u              : in batch mode (-b option), collects detailed information about blockers and prepared transactions\n"
	usage_001+=" -p              : collects information on CPU activity and memory usage, requires python psutil library (version >= 4 for memory information)\n"
	usage_001+=" -i depth        : recursive depth used by final blockers analysis (by default 2)\n"
	usage_001+=" -o columns      : choice of columns among pg_stat_activity ones separated by \",\" plus \"blockers\" (final blocking process list, 0 means one or more prepared transactions), \"to_hex(iquery)\" (query hash value), \"tquery\" (normalized query), \"to_hex(itquery)\" (hash value of normalized query). This choice replaces the default list. Default list can be explicitly set with -o \"default\". -o \"\" or -o \"constant\" can be used to consider all active sessions without any aggregation. -o option can be set several times to display results from different angles\n"
	usage_001+=" -k iterations   : prematurely stops the collection if it returns no information \"iterations\" times consecutively. This option is not effective on a read only cluster (-b H option).\n"
	usage_001+=" -l              : in interactive mode, displays I/O latency (in milliseconds) and cache evictions with PostgreSQL 16 and superior versions \n"	
	usage_001+=" -C L|U          : creates a repository schema than can be used to store data collected in batch mode (tables are logged with L argument, unlogged with U argument), creates a user with select/insert privileges and a user with select privileges on repository tables and exits.\n"	
	usage_001+=" -D              : drops the repository schema, drops the users created by -C option and exits\n"
	usage_001+=" -F informations : can be combined with -b F option to give connection informations to a traqueur repository (default \"host 'traqueur', dbname 'traqueur', port '5432'\")\n"
	usage_001+=" -A role         : can be combined with -C, -D, -b F and -F options to indicate the PostgreSQL role having insert and select privileges on repository tables (default traqueur_agent)\n"
	usage_001+=" -R role         : can be combined with -C and -D options to indicate the PostgreSQL role having select privileges on repository tables (default traqueur_dashboard)\n"
	usage_001+=" -S schema       : can be combined with -C, -D, -L, -b F and -F options to indicate the schema of the repository (default traqueur)\n"
	usage_001+=" -N              : can be combined with -b F option, in this case no password is used for the user mapping between the PostgreSQL user executing the traqueur and the PostgreSQL user of the repository\n"
	usage_001+=" -L              : loads a flat file produced on a hot standby in a repository created by -C option, removes the loaded data from the file and exits. Target cluster and hot standby cluster must be in the same major PostgreSQL version\n"
	usage_001+=" -H folder       : this option can be used in interactive mode or with -b F option to use flat files stored in \"folder\" instead of tables. It is mandatory on a read-only cluster (hot standby).\n"
	usage_001+=" -K              : removes obsolete work files traqueur.pid and stops batch traqueur processes, can be combined with -c option\n"
	usage_001+=" priority        : priority order of special options is -t -K -q -L -C -D -r -e -m -z\n"
	
	error_001_psql="ERROR, psql command not found, check \$PATH"
	error_002_options="ERROR, invalid options specified"
	error_003_bonnie="ERROR, bonnie++ command not found"
	error_004_duree="ERROR, duration argument provided after -d must be an integer >= 0"
	error_005_fenetre="ERROR, retention window argument provided after -m must be an integer >= 0"
	error_006_verbosite="ERROR, verbosity level argument provided after -v must be an integer between 0 and 3"
	error_007_sommeil="ERROR, interval in hundredths of a second between 2 queries of pg_stat_activity must be an integer > 0"
	error_008_espace="ERROR, not enough space in "
	error_009_espace="ERROR, required space : "
	error_010_espace="ERROR, free space or indicate a different folder setting variable "
	error_011_gcc="ERROR, gcc command not found"
	error_012_echec="FAILURE"
	error_013_choix_mode_journalisation="ERROR, arguments of options -b -e and -C must be L (logged) or U (unlogged). Option -b also accepts F (foreign)"
	error_014_profondeur_analyse_verrous="ERROR, recursive depth argument must be a positive integer >= 0"
	error_015_postgresql_version="ERROR, feature not available with this version of PostgreSQL "
	error_016_bellard_bonnie="ERROR, argument provided after -t must be 1, 2, 3, 4 or 5"
	error_017_rapport="ERROR, argument provided after -r must be D, L or H"
	error_018_stop_collection="ERROR, iterations argument provided after -k must be an integer >= 1"
	error_019_affichage="ERROR, argument provided after -a must be t, x or tx"
	error_020_plpython="ERROR, no available plpython extension"
	error_021_track_io_timing="ERROR, track_io_timing = on is required to obtain I/O latency with -l argument" 
	
	warning_001_bonnie="WARNING, bonnie++ command not found, adding /usr/sbin to \$PATH"
	warning_002_espace="WARNING, free space check impossible in "
	warning_003_postgres_version="WARNING, unsupported PostgreSQL version"
	warning_004_table_introuvable="WARNING, table not found "
	warning_005_pas_de_base_traqueur="WARNING, no dedicated database found and no connection parameters provided, trying to connect without any parameter "
	warning_006_pas_connecte_base_traqueur="WARNING, working database name is not "
	warning_007_partitionnement_distant="WARNING, -j option is ignored, partitioning must be activated on the repository created by -C option"
	warning_008_utilisateur_connecte_schema="WARNING, names of connected user and schema are different :"
	warning_009_bloom_unavailable="WARNING, bloom extension is not available"
		
	info_000_version="traqueur ${version} - https://pgphil.ovh - performance tool for PostgreSQL ${min_pg_version} => ${max_pg_version}"
	info_001_preparation_traque="INFORMATION, sql preparation ..."
	info_002_execution_traque="INFORMATION, sql execution ..."
	info_003_bonnie="INFORMATION, latency test with bonnie++ ..."
	info_004_base_traqueur="INFORMATION, no connection database provided, connecting to dedicated database ... "
	info_006_rapport="INFORMATION, reporting ... "
	info_007_menage="INFORMATION, deleting data collected in batch mode ... "
	info_008_bellard="INFORMATION, CPU test ..."
	info_009_change_journalisation="INFORMATION, altering logging mode of traqueur tables ... "
	info_010_execution_traque_batch="INFORMATION, sql execution ..."
	info_011_table_introuvable="INFORMATION, table not found "		
	info_012_suppression_lignes="INFORMATION, deletion OK, % lines deleted "	
	info_014_postgres_version="INFORMATION, PostgreSQL version : "
	info_015_connecte_base_traqueur="INFORMATION, connected to dedicated database"	
	info_020_creation_repository="INFORMATION, creating repository ... "
	info_021_destruction_repository="INFORMATION, removing repository ... "
	info_022_creation_user_monitoring_interactif="INFORMATION, creating interactive monitoring user ... "
	info_023_score_cpu="INFORMATION, CPU score (s) ... "
	info_024_latence="INFORMATION, I/O latency ... "
	info_025_chargement_fichiers_plats="INFORMATION, loading traqueur file(s) ... "
	info_026_stop_traqueur="INFORMATION, traqueur stoppage ... "
	
	interactive_001_debut_rapport="TRAQUEUR_RAPPORT_DEBUT variable not set, provide start time, by default : current_timestamp - interval '15 minutes'"
	interactive_002_fin_rapport="TRAQUEUR_RAPPORT_FIN variable not set, provide end time, by default : current_timestamp"
	interactive_003_top_n_rapport="TRAQUEUR_RAPPORT_TOP_N variable not set, provide the number of top events and queries to report, by default : 5"
	interactive_004_filtre_rapport="TRAQUEUR_RAPPORT_FILTRE variable not set, provide filter options to apply on top events and top queries sections, by default : application_name <> 'traqueur' and backend_type <> 'autovacuum worker'  and backend_type <> 'walsender'"
	interactive_005_format_rapport="TRAQUEUR_RAPPORT_FORMAT variable not set, provide report format (aligned to obtain plain text, or html), by default : aligned"
	interactive_006_nom_rapport="TRAQUEUR_RAPPORT_NOM not set, provide path and filename for the report, by default : ${TRAQUEUR_W}/rapport_traqueur_$$.txt (or ${TRAQUEUR_W}/rapport_traqueur_$$.htm)"
	
	report_000_titre="TRAQUEUR REPORT"
	report_001_serveur="Hostname"
	report_002_borne_inferieure="Start"
	report_003_borne_superieure="End"
	report_004_infos_systeme="System information"
	report_005_charge_CPU="Average global CPU load (excluding traqueur)"
	report_006_temps_CPU_user="CPU_user_time_in_s"
	report_007_temps_CPU_systeme="CPU_system_time_in_s"
	report_008_temps_CPU_idle="CPU_idle_time_in_s"
	report_009_temps_io="CPU_io_time_in_s"
	report_010_evenements="Events"
	report_011_requetes="Queries"
	report_012_type_evenement="Event category"
	report_013_nombre_de_detections="Detections"
	report_014_base_de_donnees="Database"
	report_015_utilisateur="User"
	report_016_identifiant_requete="Query hash value"
	report_017_requete="Query"
	report_018_application="Application"
	report_019_nombre_executions_distinctes="Distinct executions"
	report_020_pourcentage_moyen_non_CPU="Average non-CPU activity percentage"
	report_021_max_conso_memoire="Max memory consumption"
	report_022_max_conso_swap="Max swap consumption"
	report_023_elapsed="Elapsed time"
	report_024_dbtime="DB time"
	report_025_avg_active_sessions="Average active sessions"
	report_026_nombre_detections_nonparalleles="Detections (excluding parallelism)"
	report_027_latence="I/O latency (in milliseconds) and cache evictions"
	report_028_latence_lectures="Reads latency"
	report_029_latence_ecritures="Writes latency"
	report_030_latence_ecritures_permanentes="Writebacks latency"	
	report_031_latence_extensions_fichiers="Extends latency"
	report_032_latence_fsyncs="Fsyncs latency"	
	report_033_evictions="Evictions"		
	report_034_total_memory="Total physical memory (excluding swap, in Mb)"
	report_035_min_memory_occupation="Minimal memory occupation (percentage)"
	report_036_avg_memory_occupation="Average memory occupation (percentage)"
	report_037_max_memory_occupation="Maximal memory occupation (percentage)"
	report_038_total_swap="Total allocated swap (in Mb)"
	report_039_min_swap_occupation="Minimal swap occupation (percentage)"
	report_040_avg_swap_occupation="Average swap occupation (percentage)"
	report_041_max_swap_occupation="Maximal swap occupation (percentage)"
	report_042_swapped_memory="Total swapped memory"
	
fi

# FIN USAGE ERROR WARNING INTERACTION MESSAGES

declare -i GLOBAL_RESULT=0


if [[ -z ${TRAQUEUR_DATABASE+x} ]]; then
	declare TRAQUEUR_DATABASE="traqueur"
fi

if [[ -z ${TRAQUEUR_LOCAL_SCHEMA+x} ]]; then
	declare TRAQUEUR_LOCAL_SCHEMA="traqueur"
fi

if [[ -z ${TRAQUEUR_EXTENSIONS_SCHEMA+x} ]]; then
	declare TRAQUEUR_EXTENSIONS_SCHEMA="traqueur"
fi

if [[ -z ${TRAQUEUR_USER_MONITOR_PASSWORD+x} ]]; then
	declare TRAQUEUR_USER_MONITOR_PASSWORD="76b50eefc5ee60c7e89e8sgra21c835443"
fi

if [[ -z ${TRAQUEUR_REPOSITORY_USER_INSERT_SELECT_PASSWORD+x} ]]; then
	declare TRAQUEUR_REPOSITORY_USER_INSERT_SELECT_PASSWORD="76b5003fc560c7e89e8a4021c8135443"
fi

if [[ -z ${TRAQUEUR_REPOSITORY_USER_SELECT_PASSWORD+x} ]]; then
	declare TRAQUEUR_REPOSITORY_USER_SELECT_PASSWORD="501379fc032e5d41a28559734c253df2"
fi

declare process_number=$$
export PGAPPNAME="traqueur"

usage(){
	printf "${usage_001}"
}

declare -a columns_list=()
columns_list[0]="datname as db, pid as pid, usename as pg_user, client_addr as client_ip, application_name as application, substring(coalesce(tquery, query) from 1 for 64) as query, wait_event_type as wait_event_type, blockers as blockers"
declare -i columns_list_number=0
declare duree=5
declare -i stop_collection=0
declare -i max_collections_infructueuses
declare psql_connect_string=""
declare pids_list=""
declare blocked_list=""
declare affichage
declare -i extended_psql_display=0
declare -i psutil=0
declare -i bloqueurs_information=0
declare -i general_information=0
declare general_information_commentaire="null"
declare -i nature_test=0
declare -i bellard=0
declare -i bonnie=0
declare -i normalise=0
declare -i recherche_texte=0
declare -i application_info=0
declare -i mode_batch=0
declare -i change_journalisation_mode=0
declare -i partitionnement=0
declare -i menage=0
declare fenetre_menage=0
declare table_persistence="temporary"
declare table_journalisation_mode="unlogged"
declare -i raz=0
declare psql_timing="off"
declare -i rapport=0
declare -i pg_latence=0
declare type_rapport=""
declare profondeur_analyse_verrous=2
declare pg_sleep_intervalle=10
declare verbosite=3
declare repository_user_insert_select="traqueur_agent"
declare repository_user_select="traqueur_dashboard"
declare repository_schema="traqueur"
declare -i creation_user_monitor_interactif=0
declare  user_monitor_interactif="traqueur_monitor"
declare -i creation_repository_schema=0
declare -i destruction_repository_schema=0
declare repository_connect_informations=""
declare -i stockage_distant=0
declare -i pas_de_mot_de_passe_user_mapping=0
declare -i lecture_seule=0
declare dossier_fichiers_plats="${PGDATA}/traqueur/"
declare -i charge_fichiers_plats=0
declare -i stop_traqueur=0

s(){
	echo "$1 " >>  ${TRAQUEUR_W}/traqueur.${process_number}
}

spf(){
	printf "$1 " >>  ${TRAQUEUR_W}/traqueur.${process_number}
}


unconditional_error(){
	echo $1
}

error(){
	if [[ ${verbosite} -ge 1 ]]; then
		echo $1
	fi	
}

warning(){
	if [[ ${verbosite} -ge 2 ]]; then
		echo $1	
	fi
}

information(){
	if [[ ${verbosite} -ge 3 ]]; then
		echo $1	
	fi
}

interactive(){
	echo $1	
}

space_check(){
	declare -i free_space
	free_space=`df -P -k $1 |  tail -1 | awk {'print $4'}`		
	if [[ $free_space -gt $2 ]]; then
		return 0
	else
		return 1
	fi
}

del_work_files(){
	rm -f ${TRAQUEUR_W}/traqueur.$1
}

del_bellard_files(){
	rm -f ${TRAQUEUR_W}/traqueur_bellard_*_${process_number}.c
	rm -f ${TRAQUEUR_W}/traqueur_bellard_*_${process_number}
}

get_track_io_timing(){
	t_io_t=`psql ${psql_connect_string} -c "SELECT current_setting('track_io_timing')" -t -A -q -X`
	echo ${t_io_t}
}

while getopts "a:b:c:d:e:fg:hi:jk:m:no:lpq:rs:t:uv:w:yzA:C:DF:H:KLNR:S:" options 
do case $options in 
	t) nature_test="${OPTARG}"
	   if [[ ${nature_test} =~ ^[\-0-9]+$ ]] && (( nature_test > 0)) && (( nature_test <= 4)); then
		bellard=${nature_test}
	   elif [[ ${nature_test} -eq 5 ]]; then
		bonnie=1
	   else
		unconditional_error "${error_016_bellard_bonnie}"
		usage	
		exit 1
	   fi
	   ;;
	b)  mode_batch=1
	    choix_journalisation_mode="${OPTARG}"
	    if [[ ${choix_journalisation_mode} == "L" ]]; then
			table_journalisation_mode=""			
	    elif [[ ${choix_journalisation_mode} == "U" ]]; then
			table_journalisation_mode="unlogged"			
	    elif [[ ${choix_journalisation_mode} == "F" ]]; then
			stockage_distant=1		
	    elif [[ ${choix_journalisation_mode} == "H" ]]; then
			lecture_seule=1		
	    else
			error "${error_013_choix_mode_journalisation}"
			usage
			exit 1
	    fi
	    table_persistence=""
	    ;;
	c)  psql_connect_string="${OPTARG}"				
	    ;;
	d)  duree="${OPTARG}"
	    if [[ ${duree} =~ ^[\-0-9]+$ ]] && ((duree >= 0 )); then
		:
	    else
		error "${error_004_duree}"
		usage
		exit 1
	    fi		
	    ;;
	e)  choix_journalisation_mode="${OPTARG}"
	    if [[ ${choix_journalisation_mode} == "L" ]]; then
		table_journalisation_mode="logged"			
	    elif [[ ${choix_journalisation_mode} == "U" ]]; then
		table_journalisation_mode="unlogged"			
	    else
		error "${error_013_choix_mode_journalisation}"
		usage
		exit 1
	    fi
	    change_journalisation_mode=1
	    ;;
	f) recherche_texte=1
	   ;;
	l) pg_latence=1
	   ;;
	g) general_information=1
	   general_information_commentaire=${OPTARG//\'/\'\'}
	   ;;
	h) usage
	   exit 0
	   ;;
	i)  profondeur_analyse_verrous="${OPTARG}"
	    if [[ ${profondeur_analyse_verrous} =~ ^[\-0-9]+$ ]] && ((profondeur_analyse_verrous >= 0 )); then
		:
	    else
		error "${error_014_profondeur_analyse_verrous}"
		usage
		exit 1
	    fi
	    ;;
	j)  partitionnement=1
	    ;;	    
	k)  stop_collection=1
	    max_collections_infructueuses="${OPTARG}"
 	    if [[ ${max_collections_infructueuses} =~ ^[\-0-9]+$ ]] && ((max_collections_infructueuses >= 1 )); then
		:
	    else
		error "${error_018_stop_collection}"
		usage
		exit 1
	    fi		
	    ;;
	m) menage=1	
	   fenetre_menage="${OPTARG}"
	   if [[ ${fenetre_menage} =~ ^[\-0-9]+$ ]] && ((fenetre_menage >= 0 )); then
	       :
	    else
	        error "${error_005_fenetre}"
	        usage
	        exit 1
	    fi
	    ;;
	n) normalise=1
	   ;;
	o) choix_colonnes="${OPTARG,,}"
	   if [[ ${choix_colonnes} == "defaut" ]] || [[ ${choix_colonnes} == "default" ]]; then 
		columns_list[$columns_list_number]="datname as db, pid as pid, usename as pg_user, client_addr as client_ip, application_name as application, substring(coalesce(tquery, query) from 1 for 64) as query, wait_event_type as wait_event_type, blockers as blockers"		
	   elif  [[ ${choix_colonnes} == "" ]]; then 
		columns_list[$columns_list_number]="'' as all"
	   else
	 	columns_list[$columns_list_number]=${choix_colonnes}
	   fi		
	   let columns_list_number=columns_list_number+1
	   ;;   
	p) psutil=1
	   ;;   
	q)  creation_user_monitor_interactif=1
	    user_monitor_interactif="${OPTARG}"
	    ;;   
	r) rapport=1	   
	   ;; 
	s)  pg_sleep_intervalle="${OPTARG}"
	    if [[ ${pg_sleep_intervalle} =~ ^[\-0-9]+$ ]] && ((pg_sleep_intervalle >= 0 )); then
		:
	    else
		error "${error_007_sommeil}"
		usage
		exit 1
	    fi
	    ;;
	a) affichage=${OPTARG,,}
	   if [[ ${affichage} = "tx" ]] || [[ ${affichage} = "xt" ]]; then
	   	   psql_timing="on"
		   extended_psql_display=1
		elif  [[ ${affichage} = "t" ]]; then
           psql_timing="on"		
		elif  [[ ${affichage} = "x" ]]; then
		   extended_psql_display=1
		else
		   error "${error_019_affichage}"
		   usage
		   exit 1
		fi   
	   ;;	   
	u) bloqueurs_information=1
	   ;;
	v) verbosite="${OPTARG}"
	   if [[ ${verbosite} =~ ^[\-0-9]+$ ]] && (( verbosite <= 3)); then
		:
	   else
		unconditional_error "${error_006_verbosite}"
		usage	
	 	exit 1
	   fi
	   ;;
	w) pids_list="AND pid in ("${OPTARG}")"
	   blocked_list="where blocked in ("${OPTARG}")"
	   ;;
	y) application_info=1
	   ;;
	z) raz=1
	   ;;
	A)  repository_user_insert_select="${OPTARG}"
	    ;;               	   	          
	C)  creation_repository_schema=1 
	    choix_journalisation_mode="${OPTARG}"
	    if [[ ${choix_journalisation_mode} == "L" ]]; then
			table_journalisation_mode=""			
	    elif [[ ${choix_journalisation_mode} == "U" ]]; then
			table_journalisation_mode="unlogged"			
	    elif [[ ${choix_journalisation_mode} == "F" ]]; then
			stockage_distant=1			
	    else
			error "${error_013_choix_mode_journalisation}"
			usage
			exit 1
	    fi
	    table_persistence=""	    
	    ;;
	D)  destruction_repository_schema=1	    
	    ;;
	F)  repository_connect_informations="${OPTARG}"
	    ;;
	H)  dossier_fichiers_plats="${OPTARG}"
	    ;;
	K)  stop_traqueur=1
	    ;;
	L) charge_fichiers_plats=1;
	    ;;   
	N)  pas_de_mot_de_passe_user_mapping=1
	    ;;    	     
	R)  repository_user_select="${OPTARG}"
	    ;;
	S)  repository_schema="${OPTARG}"
	    ;;
	:) usage
	   exit 1
	   ;;
	*) usage
	   exit 1
	;;
esac 
done
shift $((OPTIND-1))

information "${info_000_version}"

if [[ ${bellard} -eq 1 ]]; then
	space_check "${TRAQUEUR_W}" 600000
	if [[ $? -eq 1 ]]; then
		error "${error_008_espace} ${TRAQUEUR_W}"
		error "${error_009_espace} 600000k"		
		exit 1
	elif [[ $? -eq 2 ]]; then		
		warning "${warning_002_espace}${TRAQUEUR_W}"
	fi	
	type gcc > /dev/null 2>&1
	if [[ $? -ne 0 ]]; then
		error "${error_011_gcc}"
		exit 1
	fi
	information "${info_008_bellard}" 
	
	# Debut code Fabrice BELLARD
	declare optimus_prime="int m=1811939329,N=1,t[1<<26]={2},a,*p,i,e=73421233,s,c,U=1;g(d,h){for(i=s;i<1<<"
	optimus_prime+="25;i*=2)d=d*1LL*d%m;for(p=t;p<t+N;p+=s)for(i=s,c=1;i;i--)a=p[s]*(h?c:1LL)%m,p[s]"
	optimus_prime+="=(m*1U+*p-a)*(h?1LL:c)%m,*p=(a*1U+*p)%m,p++,c=c*1LL*d%m;}main(){while(e/=2){N*=2"
	optimus_prime+=";U=U*1LL*(m+1)/2%m;for(s=N;s/=2;)g(136,0);for(p=t;p<t+N;p++)*p=*p*1LL**p%m*U%m;"
	optimus_prime+="for(s=1;s<N;s*=2)g(839354248,1);for(a=0,p=t;p<t+N;)a+=*p<<(e&1),*p++=a%10,a/=10;"
	optimus_prime+="}while(!*--p);for(t[0]--;p>=t;)putchar(48+*p--);}" 
	# Fin code Fabrice BELLARD
	
	case ${OS} in
		Linux|OSF1|SunOS|Interix)
			declare compilateur="gcc -w"
			;;
		HP-UX) 
			declare compilateur="gcc -w "
			;;
		AIX)
			declare compilateur="gcc -w -maix64 "
			;;
		*)	
			declare compilateur="gcc -w"
			;;	
	esac	
	declare debut_bellard=`date +%s`
	echo ${optimus_prime} > ${TRAQUEUR_W}/traqueur_bellard_optimus_prime_${process_number}.c
	if [[ `${compilateur} ${TRAQUEUR_W}/traqueur_bellard_optimus_prime_${process_number}.c -o ${TRAQUEUR_W}/traqueur_bellard_optimus_prime_${process_number} && ${TRAQUEUR_W}/traqueur_bellard_optimus_prime_${process_number}` == *"217671164956287190498687010073391086436351" ]]; then
		declare fin_bellard=`date +%s`	
		let bellard_score=${fin_bellard}-${debut_bellard}
		information "${info_023_score_cpu} ${bellard_score}"	
	else
		error ${error_012_echec}	
		GLOBAL_RESULT=1	
	fi
	del_bellard_files
	exit ${GLOBAL_RESULT}
fi

if [[ ${bellard} -ge 2 ]] && [[ ${bellard} -le 4 ]]; then
		space_check "${TRAQUEUR_W}" 100
		if [[ $? -eq 1 ]]; then
			error "${error_008_espace} ${TRAQUEUR_W}"
			error "${error_009_espace} 100k"		
			exit 1
		elif [[ $? -eq 2 ]]; then		
			warning "${warning_002_espace}${TRAQUEUR_W}"
		fi	
		type gcc > /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			error "${error_011_gcc}"
			exit 1
		fi
		information "${info_008_bellard}" 
		# Debut code Fabrice BELLARD
		declare pic="#include <stdlib.h>\n"
		pic+="#include <stdio.h>\n"
		pic+="#include <math.h>\n"
		if [[ ${bellard} -eq 3 ]]; then
			pic+="#define HAS_LONG_LONG\n"
		fi 
		pic+="#ifdef HAS_LONG_LONG\n"
		pic+="#define mul_mod(a,b,m) (( (long long) (a) * (long long) (b) ) % (m))\n"
		pic+="#else\n"
		pic+="#define mul_mod(a,b,m) fmod( (double) a * (double) b, m)\n"
		pic+="#endif\n"
		pic+="int inv_mod(int x, int y)\n"
		pic+="{int q, u, v, a, c, t; u = x; v = y; c = 1; a = 0; do { q = v / u; t = c; c = a - q * c; a = t; t = u; u = v - q * u; v = t; } while (u != 0); a = a % y; if (a < 0) a = y + a; return a;}\n"
		pic+="int inv_mod2(int u, int v){ int u1, u3, v1, v3, t1, t3; u1 = 1; u3 = u; v1 = v; v3 = v; if ((u & 1) != 0) { t1 = 0; t3 = -v; goto Y4; } else { t1 = 1; t3 = u; } do { do { if ((t1 & 1) == 0) {\n"
		pic+="t1 = t1 >> 1; t3 = t3 >> 1; } else { t1 = (t1 + v) >> 1; t3 = t3 >> 1; } Y4:; } while ((t3 & 1) == 0); if (t3 >= 0) { u1 = t1; u3 = t3; } else { v1 = v - t1; v3 = -t3; } t1 = u1 - v1; t3 = u3 - v3;\n"
		pic+="if (t1 < 0) { t1 = t1 + v; } } while (t3 != 0); return u1;}int pow_mod(int a, int b, int m){ int r, aa; r = 1; aa = a; while (1) { if (b & 1) r = mul_mod(r, aa, m); b = b >> 1; if (b == 0) break;\n"
		pic+="aa = mul_mod(aa, aa, m); } return r;}int is_prime(int n){ int r, i; if ((n % 2) == 0) return 0; r = (int) (sqrt(n)); for (i = 3; i <= r; i += 2) if ((n % i) == 0) return 0; return 1;}\n"
		pic+="int next_prime(int n){ do { n++; } while (!is_prime(n)); return n;}\n"
		pic+='#define DIVN(t,a,v,vinc,kq,kqinc)                          \ \n'
		pic+='{                                                                                            \ \n'
		pic+='kq+=kqinc;                                                                      \ \n'
		pic+='if (kq >= a) {                                                    \ \n'
		pic+='  do { kq-=a; } while (kq>=a);                   \ \n'
		pic+='  if (kq == 0) {                                                  \ \n'
		pic+='    do {                                                                \ \n'
		pic+='              t=t/a;                                                                   \ \n'
		pic+='              v+=vinc;                                                             \ \n'
		pic+='    } while ((t % a) == 0);                                              \ \n'
		pic+='  }                                                                                        \ \n'
		pic+='}                                                                                          \ \n'
		pic+='} \n'
		pic+="int main(int argc, char *argv[])\n"
		pic+="{ int av, a, vmax, N, n, num, den, k, kq1, kq2, kq3, kq4, t, v, s, i, t1; double sum;\n"
		pic+="if (argc < 2 || (n = atoi(argv[1])) <= 0) { exit(1); }\n"
		pic+="N = (int) ((n + 20) * log(10) / log(13.5)); sum = 0; for (a = 2; a <= (3 * N); a = next_prime(a)) { vmax = (int) (log(3 * N) / log(a)); if (a == 2) { vmax = vmax + (N - n); if (vmax <= 0)\n"
		pic+="continue; } av = 1; for (i = 0; i < vmax; i++) av = av * a; s = 0; den = 1; kq1 = 0; kq2 = -1; kq3 = -3; kq4 = -2; if (a == 2) { num = 1; v = -n; } else { num = pow_mod(2, n, av);\n"
		pic+="v = 0; } for (k = 1; k <= N; k++) { t = 2 * k; DIVN(t, a, v, -1, kq1, 2); num = mul_mod(num, t, av); t = 2 * k - 1; DIVN(t, a, v, -1, kq2, 2); num = mul_mod(num, t, av); t = 3 * (3 * k - 1);\n"
		pic+="DIVN(t, a, v, 1, kq3, 9); den = mul_mod(den, t, av); t = (3 * k - 2); DIVN(t, a, v, 1, kq4, 3); if (a != 2) t = t * 2; else v++; den = mul_mod(den, t, av); if (v > 0) { if (a != 2)\n"
		pic+="t = inv_mod2(den, av); else t = inv_mod(den, av); t = mul_mod(t, num, av); for (i = v; i < vmax; i++) t = mul_mod(t, a, av); t1 = (25 * k - 3); t = mul_mod(t, t1, av); s += t; if (s >= av) s -= av; }} t = pow_mod(5, n - 1, av); s = mul_mod(s, t, av); sum = fmod(sum + (double) s / (double) av, 1.0); } printf(\"%09d\", (int) (sum * 1e9)); return 0;}\n"
		# Fin code Fabrice BELLARD
		case ${OS} in
		Linux|OSF1|SunOS|Interix)
			declare compilateur="gcc -w "
			;;
		HP-UX) 
			declare compilateur="gcc -w -maix64 "
			;;
		AIX)
			declare compilateur="gcc -w "
			;;
		*)	
			declare compilateur="gcc -w "
			;;	
		esac
		declare -i decimales_pi
		declare -i resultat_pi_attendu
		if [[ ${bellard} -eq 2 ]]; then
			decimales_pi=40000
			resultat_pi_attendu="119299015"
		elif [[ ${bellard} -eq 3 ]]; then
			decimales_pi=80000
			resultat_pi_attendu="694828436"
		else	
			decimales_pi=1000
			resultat_pi_attendu="938095257"
		fi 	
		declare debut_bellard=`date +%s`
	
		echo -e "${pic}" > ${TRAQUEUR_W}/traqueur_bellard_pi_${process_number}.c
		if [[ `${compilateur} ${TRAQUEUR_W}/traqueur_bellard_pi_${process_number}.c -o ${TRAQUEUR_W}/traqueur_bellard_pi_${process_number} -lm && ${TRAQUEUR_W}/traqueur_bellard_pi_${process_number} ${decimales_pi}` == "${resultat_pi_attendu}" ]]; then
			declare fin_bellard=`date +%s`	
			let bellard_score=${fin_bellard}-${debut_bellard}
			information "${info_023_score_cpu} ${bellard_score}"	
		else
			error ${error_012_echec}	
			GLOBAL_RESULT=1	
		fi
		del_bellard_files
		exit ${GLOBAL_RESULT}
fi
		
if [[ ${bonnie} -eq 1 ]]; then
	if [[ -z ${PGDATA+x} ]]; then
		PGDATA="/var/lib/postgresql/15/main"
	fi
	space_check "$PGDATA" 1000000
	if [[ $? -eq 1 ]]; then
		error "${error_008_espace} $PGDATA/base"
		error "${error_009_espace} 1G"
		error "${error_010_espace}PGDATA"
		exit 1
	elif [[ $? -eq 2 ]]; then		
		warning "${warning_002_espace}PGDATA"
	fi	
	type bonnie++ > /dev/null 2>&1
	if [[ $? -ne 0 ]]; then
		warning "${warning_001_bonnie}"
		export PATH=$PATH:/usr/sbin
		type bonnie++ > /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			error "${error_003_bonnie}"
			exit 1
		fi
	fi 
	information "${info_003_bonnie}" 
	declare deb_bonnie=`date +%s`
	declare latence=`{ bonnie++ -d "${PGDATA}/base" -b -f -n 0  -r 256 2>/dev/null || echo "Latency NULL NULL NULL ${error_012_echec}" ;} |& awk '(substr($0,1,7)=="Latency") {print $5}'`
	let GLOBAL_RESULT=GLOBAL_RESULT+$?	
	declare fin_bonnie=`date +%s`
	information "${info_024_latence} ${latence}"
	if [[ ${latence} == *${error_012_echec} ]]; then
		GLOBAL_RESULT=1		
	fi
	exit ${GLOBAL_RESULT}
fi

type psql > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
	error "${error_001_psql}"
	exit 1
fi 

declare base

if [[ ${psql_connect_string} != *"-d"* ]]; then
	base=`psql ${psql_connect_string} -c "SELECT datname from pg_database where datname = '${TRAQUEUR_DATABASE}'" -t -A -q -X`
	if [[ ${base} == "${TRAQUEUR_DATABASE}" ]]; then 
	    information "${info_004_base_traqueur}"
		psql_connect_string="${psql_connect_string}"" -d ${TRAQUEUR_DATABASE}"
	else
		warning "${warning_005_pas_de_base_traqueur}"
	fi
fi

base=`psql ${psql_connect_string} -c "SELECT current_database()" -t -A -q -X`
if  [[ ${base} != "${TRAQUEUR_DATABASE}" ]]; then
	warning "${warning_006_pas_connecte_base_traqueur} ${TRAQUEUR_DATABASE}"
else
	information "${info_015_connecte_base_traqueur} ${TRAQUEUR_DATABASE}"
fi

declare postgres_user=`psql ${psql_connect_string} -c "SELECT current_user" -t -A -q -X`
if [[ ${postgres_user} != ${TRAQUEUR_LOCAL_SCHEMA} ]] && [[ ${base} != "${TRAQUEUR_DATABASE}" ]]; then
	warning "${warning_008_utilisateur_connecte_schema} ${postgres_user} ${TRAQUEUR_LOCAL_SCHEMA}"
fi

declare superuser=`psql ${psql_connect_string} -c "SELECT usesuper FROM pg_user WHERE usename = CURRENT_USER" -t -A -q -X` 

declare -i postgres_version=`psql ${psql_connect_string} -c "SELECT current_setting('server_version_num')" -t -A -q -X`

declare plpython_extension=`psql ${psql_connect_string} -c "SELECT name FROM pg_available_extensions where name in ('plpython3u','plpythonu') order by name desc fetch first 1 row only" -t -A -q -X`
if [[ -z ${plpython_extension} ]] && [[ ${psutil} -eq 1 ]]; then
	error "${error_020_plpython}"
	exit 1
fi

information "${info_014_postgres_version}"${postgres_version}
if [[ ${postgres_version} -lt 120000 ]] || [[  ${postgres_version} -ge 180000 ]]; then
	warning "${warning_003_postgres_version}"							
fi
if [[ ${postgres_version} -lt 160000 ]] && [[  ${pg_latence} -eq 1 ]]; then
	error "${error_015_postgresql_version}"	
	exit 1
fi
if [[  ${pg_latence} -eq 1 ]]; then
	track_io_timing=$(get_track_io_timing)
	if [[ ${track_io_timing} = "on" ]]; then
		:
	else
		error "${error_021_track_io_timing}"	
		exit 1
	fi	
fi
if [[ ${pg_latence} -eq 0 ]] && [[ ${mode_batch} -eq 1 ]] && [[ ${postgres_version} -ge 160000 ]]; then
	track_io_timing=$(get_track_io_timing)
	if [[ ${track_io_timing} = "on" ]]; then
		pg_latence=1
	fi	
fi

if [[ ${pids_list} == "" ]]  && [[ ${blocked_list} == "" ]]; then
	pids_list="AND pid in (select pid from pg_stat_activity where coalesce(wait_event_type,'') not in ('Activity', 'Timeout'))"
	blocked_list="where blocked in (select pid from pg_stat_activity where coalesce(wait_event_type,'') not in ('Activity', 'Timeout'))"
fi


declare brin_autosummarize="WITH (autosummarize)"
declare -i bloom_available=`psql ${psql_connect_string} -c "SELECT 1 from pg_available_extensions where name = 'bloom'" -t -A -q -X`
if [[ ${bloom_available} -eq 1 ]]; then
	:
else
	warning "${warning_009_bloom_unavailable}"
fi

create_function_traqueur_system(){
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_system() RETURNS varchar "
	s "AS \$\$"
	s "import platform"
	s "return platform.system()	"
	s "\$\$ LANGUAGE ${plpython_extension};"
}	
		
create_function_traqueur_hostname(){	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_hostname() RETURNS varchar "
	s "AS \$\$"
	s "import socket"
	s "return socket.gethostname()	"
	s "\$\$ LANGUAGE ${plpython_extension};"
}
	
create_function_traqueur_times(){	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_times()"
 	s "RETURNS character varying"
 	s "LANGUAGE ${plpython_extension}"
	s "AS \$function\$"
	s "import psutil"
	s "return psutil.cpu_times()"
	s "\$function\$"
	s ";"
}

create_function_traqueur_virtual_memory(){	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_virtual_memory()"
 	s "RETURNS character varying"
 	s "LANGUAGE ${plpython_extension}"
	s "AS \$function\$"
	s "import psutil"
	s "return psutil.virtual_memory()"
	s "\$function\$"
	s ";"
}

create_function_traqueur_swap_memory(){	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_swap_memory()"
 	s "RETURNS character varying"
 	s "LANGUAGE ${plpython_extension}"
	s "AS \$function\$"
	s "import psutil"
	s "return psutil.swap_memory()"
	s "\$function\$"
	s ";"
}

create_function_maxsumbydtcol_sfunc(){
	s "create function pg_temp.maxsumbydtcol_sfunc(agg_state json,  val json)"
	s "returns json"
	s "immutable"
	s "language plpgsql"
	s "as \$BODY\$"
	s "declare"
	s "current_sum bigint;"
	s "begin"
	s "if (val->>'f1') = (agg_state->>'f1') then"
	s "current_sum := (agg_state->>'f2')::bigint + (val->>'f2')::bigint;"       
	s "else"     
	s "	current_sum := (val->>'f2')::bigint;"
	s "end if;"
	s "if (agg_state->>'f3')::bigint >= current_sum then"
	s "	return row_to_json(row(val->>'f1', current_sum, agg_state->>'f3'));"    
	s "else  "
	s "	return row_to_json(row(val->>'f1', current_sum, current_sum));"
	s "end if;  "
	s "end;"
	s "\$BODY\$;"
}

create_function_maxsumbydtcol_finalfunc(){	
	s "create function pg_temp.maxsumbydtcol_finalfunc(agg_state json)"
	s "returns bigint"
	s "immutable"
	s "strict"
	s "language plpgsql"
	s "as \$BODY\$"
	s "begin"
	s "return (agg_state->>'f3')::bigint;"
	s "end;"
	s "\$BODY\$;"
}

create_aggregate_maxsumbydtcol(){
	s "create aggregate pg_temp.maxsumbydtcol (json)"
	s "("
	s "sfunc = pg_temp.maxsumbydtcol_sfunc,"
	s "stype = json,"
	s "initcond  = '{}',"
	s "finalfunc = pg_temp.maxsumbydtcol_finalfunc"
	s ");"
}		
	
create_procedure_function_traqueur_collection(){	
	if [[ $1 -eq 1 ]]; then
		if [[ ${stop_collection} -eq 0 ]]; then
			s "CREATE OR REPLACE PROCEDURE pg_temp.traqueur_collection()"			
		else	
			s "CREATE OR REPLACE PROCEDURE pg_temp.traqueur_collection(max_collections_infructueuses IN integer)"
		fi	
	else
		if [[ ${stop_collection} -eq 0 ]]; then
			s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_collection() returns void"			
		else
			s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_collection(max_collections_infructueuses integer) returns void"
		fi	
	fi		
 	s "LANGUAGE plpgsql"
	s "AS \$\$"
	s "DECLARE"
	s "embedded_transaction_timestamp timestamp;"
	if [[ ${stop_collection} -eq 1 ]]; then
		if [[ ${mode_batch} -eq 0 ]]; then
			s "collections_effectuees integer := 0;"			
		fi		
		s "collections_infructueuses integer := 0;"
		s "nb_lignes_inserees integer := 0;"
	fi	
	s "BEGIN"
	if [[ ${stop_collection} -eq 1 ]]; then
		if [[ ${mode_batch} -eq 0 ]]; then
			s "CREATE TEMPORARY TABLE iterations_reelles(valeur INTEGER);"			
		fi
	fi
	s "for i in 1..${iterations} loop"	
	s "embedded_transaction_timestamp := clock_timestamp();"
	s "with"
	s "recursive blocked_blocker_desc(blocked, blocker, top_blocker, path, cycle, niveau) AS "
	s "( SELECT blocked, blocker, blocker, array[blocked_blocker.blocked], false, 1"
	s "FROM blocked_blocker "
	s "where blocker not in (select blocked from blocked_blocker)"
	s "UNION ALL "
	s "SELECT bb.blocked, h.blocked, h.top_blocker, path || bb.blocked, bb.blocked = any(path), niveau+1 FROM blocked_blocker_desc AS h join blocked_blocker AS bb on (h.blocked = bb.blocker) where not h.cycle and niveau <= ${profondeur_analyse_verrous} and bb.blocked not in (select blocked from blocked_by_top_blocker bbtb))"
	s ", waiting_locks as (SELECT distinct locktype, database, relation, page, tuple, virtualxid, transactionid, classid, objid, objsubid, coalesce(pid, 0) pid FROM pg_catalog.pg_locks WHERE NOT granted)"
	s ", all_locks as (SELECT distinct locktype, database, relation, page, tuple, virtualxid, transactionid, classid, objid, objsubid, coalesce(pid, 0) pid FROM pg_catalog.pg_locks)"
	s ", active_sessions as (SELECT * "
	if [[ ${normalise} -eq 1 ]]; then
		s ",@('x'||substr(encode(sha256(convert_to(query,'UTF8')),'hex'),1,8))::bit(32)::int iquery"
		s ", pg_temp.traqueur_normalize_query(query) tquery "
		if [[ ${postgres_version} -ge 140000 ]]; then
			s ",@('x'||substr(encode(sha256(coalesce(convert_to(query_id::text,'UTF8'),convert_to(pg_temp.traqueur_normalize_query(query),'UTF8'))),'hex'),1,8))::bit(32)::int itquery"
		else
			s ",@('x'||substr(encode(sha256(convert_to(pg_temp.traqueur_normalize_query(query),'UTF8')),'hex'),1,8))::bit(32)::int itquery"
		fi
	else
		s ",@('x'||substr(encode(sha256(convert_to(query,'UTF8')),'hex'),1,8))::bit(32)::int iquery"
		s ",null::text tquery "
		s ",null::int itquery"
	fi
	if [[ ${recherche_texte} -eq 1 ]]; then
		s ", to_tsvector('english', query) dquery "
	else
		s ",null::tsvector dquery "
	fi
	s "FROM pg_catalog.pg_stat_activity where state  = 'active' AND pid != pg_backend_pid() ${pids_list})"
	s ", blocked_blocker as (select waiting_locks.pid blocked, all_locks.pid blocker"
	s "  from"
	s "  waiting_locks"
	s "  JOIN"
	s "  all_locks"
	s "ON (all_locks.locktype = waiting_locks.locktype"
	s "AND all_locks.DATABASE IS NOT DISTINCT FROM waiting_locks.database"
	s "AND all_locks.relation IS NOT DISTINCT FROM waiting_locks.relation"
	s "AND all_locks.page IS NOT DISTINCT FROM waiting_locks.page"
	s "AND all_locks.tuple IS NOT DISTINCT FROM waiting_locks.tuple"
	s "AND all_locks.virtualxid IS NOT DISTINCT FROM waiting_locks.virtualxid"
	s "AND all_locks.transactionid IS NOT DISTINCT FROM waiting_locks.transactionid"
	s "AND all_locks.classid IS NOT DISTINCT FROM waiting_locks.classid"
	s "AND all_locks.objid IS NOT DISTINCT FROM waiting_locks.objid"
	s "AND all_locks.objsubid IS NOT DISTINCT FROM waiting_locks.objsubid"
	s "AND all_locks.pid != waiting_locks.pid)),"
	s "blocked_by_top_blocker as (select blocked, blocker from blocked_blocker where blocker not in (select blocked from blocked_blocker)),"
	s "blocked_final_blockers as (select blocked, array_agg(distinct top_blocker) final_blockers from blocked_blocker_desc ${blocked_list} group by blocked)"
	if [[ ${psutil} -eq 1 ]]; then
		s ", pids_pc(jval) as (select json_array_elements(pg_temp.traqueur_cpu_pid(array_agg(distinct pid))) as jval FROM active_sessions)"
		s ", traqueur_sessions_actives_recentes(pid, mem, swapped)  as (select * from (select pid, avg(mem), avg(swapped) from traqueur_sessions_actives WHERE dtcol > (embedded_transaction_timestamp -  greatest(20,${pg_sleep_intervalle}*2) * interval '1 second') and pid is not null group by pid) all_sessions"	
		if [[ ${mode_batch} -eq 1 ]]; then		
			s " WHERE random() <= (SELECT count(*)::float FROM (SELECT null FROM active_sessions FETCH FIRST 999 ROWS ONLY) tsa_999)/1000)"
		else
			s " )"			
		fi	
		s ", pids_mem(jval) as (select json_array_elements(pg_temp.traqueur_mem_pid(array_agg(distinct pid))) as jval FROM active_sessions"
		s "WHERE pid not in (SELECT pid FROM traqueur_sessions_actives_recentes))"
	fi
	if [[ ${psutil} -eq 1 ]]; then
		s ", active_sessions_plus as (select active_sessions.*, blocked_final_blockers.final_blockers, (CASE WHEN active_sessions.pid is not null THEN (SELECT (jval->>'pc')::float from pids_pc where jval->>'pid' = active_sessions.pid::character varying) ELSE (SELECT (jval->>'pc')::float from pids_pc where jval->>'pid' = 0::character varying) END) as pourcentage_cpu, coalesce(traqueur_sessions_actives_recentes.mem, (SELECT ((jval->>'uss')::bigint) from pids_mem where jval->>'pid' = active_sessions.pid::character varying)) as mem, coalesce(traqueur_sessions_actives_recentes.swapped, (SELECT ((jval->>'swap')::bigint) from pids_mem where jval->>'pid' = active_sessions.pid::character varying)) as swapped"
		s "from "
		s "traqueur_sessions_actives_recentes"
		s "RIGHT OUTER JOIN active_sessions ON (traqueur_sessions_actives_recentes.pid = active_sessions.pid)"
		s "FULL OUTER JOIN (select 0 as pid) zero ON (active_sessions.pid = zero.pid)"
		s "LEFT OUTER JOIN blocked_final_blockers on (active_sessions.pid = blocked_final_blockers.blocked))"
	else
		s ", active_sessions_plus as (select active_sessions.*, blocked_final_blockers.final_blockers, null::float as pourcentage_cpu, null::float as mem, null::float as swapped from active_sessions LEFT OUTER JOIN blocked_final_blockers on (active_sessions.pid = blocked_final_blockers.blocked))"
	fi
	s "INSERT INTO traqueur_sessions_actives "
	s "SELECT embedded_transaction_timestamp, active_sessions_plus.*"
	if [[ ${application_info} -eq 1 ]]; then
		s ", CASE WHEN length(application_name) - length(replace(application_name,',','')) = 5 THEN jsonb_object('{program,module,action,client_info,sofar,totalwork}', string_to_array(application_name, ',')) END" 
	else
		s ", null"
	fi	
	s "FROM   "
	s "active_sessions_plus; "	
	if [[ ${stop_collection} -eq 1 ]]; then
		s "GET DIAGNOSTICS nb_lignes_inserees = ROW_COUNT;"
		if [[ ${psutil} -eq 1 ]]; then
			s "if nb_lignes_inserees = 1 then"
		else
			s "if nb_lignes_inserees = 0 then"
		fi	
		s "collections_infructueuses := collections_infructueuses + 1;"
		s "else "
		s "collections_infructueuses := 0;"
		s "end if;"
		if [[ ${mode_batch} -eq 0 ]]; then
			s "collections_effectuees := collections_effectuees + 1;"
		fi
		s "if collections_infructueuses >= max_collections_infructueuses then"				
		s "exit;"
		s "end if;"		
	fi	
	if [[ ${general_information} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
		s "if  mod(i, 100) = 0 or i = 1 or i = ${iterations} then"
		s "insert into traqueur_cluster_information(dtcol, cluster_hostname, cluster_os_family, cluster_postgres_version, cluster_port, cluster_archive_mode, cluster_size, cluster_pretty_size, cluster_shared_buffers, cluster_processes, cluster_databases, cluster_comment) select embedded_transaction_timestamp, pg_temp.traqueur_hostname(), pg_temp.traqueur_system(), version(), (select setting from pg_settings where name = 'port'), (select upper(setting) from pg_settings where name = 'archive_mode'),(SELECT sum(pg_database_size(datname)) FROM pg_database where not datistemplate), (SELECT pg_size_pretty(sum(pg_database_size(datname))) FROM pg_database where not datistemplate), (with shared_buffers(unit, valeur, multi) as (select case when upper(unit) like '%KB%' then 1024 when upper(unit) like '%MB%' then 1024*1024 when upper(unit) like '%GB%' then 1024*1024*1024 else 0 end, setting::bigint, substring(unit from '(([0-9]+.*)*[0-9]+)')::bigint from pg_settings where name='shared_buffers') select pg_size_pretty((select unit*valeur*multi from shared_buffers)) from pg_settings where name = 'shared_buffers'), (select count(*) from pg_stat_activity), (select string_agg(datname || ' (' || pg_size_pretty(pg_database_size(datname)) || ')', ' - ') from pg_database where not datistemplate), '${general_information_commentaire}';"  
		s "end if;"
	fi			
	if [[ ${psutil} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
		s "perform pg_temp.traqueur_insert_times();"
		s "perform pg_temp.traqueur_insert_virtual_memory();"
		s "perform pg_temp.traqueur_insert_swap_memory();"
	fi
	if [[ ${general_information} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
		s "insert into traqueur_cluster_stats select embedded_transaction_timestamp, * from pg_stat_database;"
	fi
	if [[ ${pg_latence} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
		s "if mod(i, 10) = 0 or i = 1 or i = ${iterations} then"
		s "insert into traqueur_io_stats select embedded_transaction_timestamp, * from pg_stat_io;"
		s "end if;"
	fi
	if [[ ${pg_latence} -eq 1 ]] && [[ ${mode_batch} -eq 0 ]]; then
		s "if i = 1 or i = ${iterations} then"
		s "insert into traqueur_io_stats select embedded_transaction_timestamp, * from pg_stat_io;"
		s "end if;"
	fi
	if [[ ${bloqueurs_information} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
		s "with waiting_locks as (SELECT distinct locktype, database, relation, page, tuple, virtualxid, transactionid, classid, objid, objsubid, pid FROM pg_catalog.pg_locks WHERE NOT granted), "
		s "granted_locks as (SELECT distinct locktype, database, relation, page, tuple, virtualxid, transactionid, classid, objid, objsubid, pid FROM pg_catalog.pg_locks WHERE granted AND pid != pg_backend_pid()),"
		s "blockers as (select distinct granted_locks.pid"
		s "from"
		s "waiting_locks"
		s "JOIN"
		s "granted_locks"
		s "ON (granted_locks.locktype = waiting_locks.locktype"
		s "AND granted_locks.DATABASE IS NOT DISTINCT FROM waiting_locks.database"
		s "AND granted_locks.relation IS NOT DISTINCT FROM waiting_locks.relation"
		s "AND granted_locks.page IS NOT DISTINCT FROM waiting_locks.page"
		s "AND granted_locks.tuple IS NOT DISTINCT FROM waiting_locks.tuple"
		s "AND granted_locks.virtualxid IS NOT DISTINCT FROM waiting_locks.virtualxid"
		s "AND granted_locks.transactionid IS NOT DISTINCT FROM waiting_locks.transactionid"
		s "AND granted_locks.classid IS NOT DISTINCT FROM waiting_locks.classid"
		s "AND granted_locks.objid IS NOT DISTINCT FROM waiting_locks.objid"
		s "AND granted_locks.objsubid IS NOT DISTINCT FROM waiting_locks.objsubid"
		s "AND granted_locks.pid != waiting_locks.pid))"
		s ", blocking_sessions as (select * from pg_stat_activity where pid in (select pid from blockers))"
		s "insert into traqueur_bloqueurs_process select embedded_transaction_timestamp, * from blocking_sessions;"
		s "with waiting_locks as (SELECT distinct locktype, database, relation, page, tuple, virtualxid, transactionid, classid, objid, objsubid, virtualtransaction FROM pg_catalog.pg_locks WHERE NOT granted), "
		s "granted_locks as (SELECT distinct locktype, database, relation, page, tuple, virtualxid, transactionid, classid, objid, objsubid, virtualtransaction FROM pg_catalog.pg_locks WHERE granted and pid is null),"
		s "blockers as (select distinct granted_locks.virtualtransaction"
		s "from"
		s "waiting_locks"
		s "JOIN"
		s "granted_locks"
		s "ON (granted_locks.locktype = waiting_locks.locktype"
		s "AND granted_locks.DATABASE IS NOT DISTINCT FROM waiting_locks.database"
		s "AND granted_locks.relation IS NOT DISTINCT FROM waiting_locks.relation"
		s "AND granted_locks.page IS NOT DISTINCT FROM waiting_locks.page"
		s "AND granted_locks.tuple IS NOT DISTINCT FROM waiting_locks.tuple"
		s "AND granted_locks.virtualxid IS NOT DISTINCT FROM waiting_locks.virtualxid"
		s "AND granted_locks.classid IS NOT DISTINCT FROM waiting_locks.classid"
		s "AND granted_locks.objid IS NOT DISTINCT FROM waiting_locks.objid"
		s "AND granted_locks.objsubid IS NOT DISTINCT FROM waiting_locks.objsubid"
		s "))"
		s ", blocking_transactions as (select * from pg_prepared_xacts where transaction in (select transactionid from pg_locks where transactionid is not null and virtualtransaction in (select virtualtransaction from blockers)))"	
		s "insert into traqueur_bloqueurs_transactions select embedded_transaction_timestamp, * from blocking_transactions;"
	fi
	if [[ ${pg_sleep_intervalle_ms} -ne 0 ]]; then		
		s "perform CASE WHEN clock_timestamp() - embedded_transaction_timestamp < INTERVAL '${pg_sleep_intervalle_ms} millisecond' THEN (SELECT true FROM pg_sleep_for(INTERVAL '	${pg_sleep_intervalle_ms} millisecond'-(clock_timestamp() - embedded_transaction_timestamp))) ELSE false END;"		
	fi
	if [[ $1 -eq 1 ]]; then
		s "commit;"
	else
		s "perform pg_stat_clear_snapshot();"
	fi	
	s "end loop;"
	if [[ ${stop_collection} -eq 1 ]]; then
		if [[ ${mode_batch} -eq 0 ]]; then
			s "INSERT INTO iterations_reelles(valeur) values(collections_effectuees);"			
		fi
	fi
	s "END"
	s "\$\$"
	s ";"
}

anonymous_traqueur_collection(){	
	s "DO"
 	s "LANGUAGE plpgsql"
	s "\$\$"
	s "DECLARE"
	s "embedded_transaction_timestamp timestamp;"
	s "BEGIN"
	s "for i in 1..${iterations} loop"	
	s "embedded_transaction_timestamp := clock_timestamp();"
	s "COPY (SELECT clock_timestamp(), *"
	s ",@('x'||substr(encode(sha256(conver_to(query,'UTF8')),'hex'),1,8))::bit(32)::int iquery"
	s ",null::text tquery "
	s ",null::int itquery"
	s ", null::tsvector as dquery,null::integer[] as blockers, 0::float as pourcentage_cpu, 0::bigint as mem, 0::bigint as swapped, null::jsonb as application_info "
	s "FROM pg_catalog.pg_stat_activity where state  = 'active' AND pid != pg_backend_pid() ${pids_list})"	
	s " TO PROGRAM 'cat >> ${dossier_fichiers_plats}/traqueur_sessions_actives.txt';"
	if [[ ${pg_sleep_intervalle_ms} -ne 0 ]]; then		
		s "perform CASE WHEN clock_timestamp() - embedded_transaction_timestamp < INTERVAL '${pg_sleep_intervalle_ms} millisecond' THEN (SELECT true FROM pg_sleep_for(INTERVAL '	${pg_sleep_intervalle_ms} millisecond'-(clock_timestamp() - embedded_transaction_timestamp))) ELSE false END;"		
	fi
	s "commit;"
	s "end loop;"
	s "END"
	s "\$\$"
	s ";"
}

add_partitions(){	
	s "DO"
	s "\$BODY\$"
	s "DECLARE"
	s "range_informations cursor for with recursive serie(i, l, u) as (values(1, date_trunc('day', current_timestamp), date_trunc('day', current_timestamp)+ interval '1 day') UNION ALL select i + 1,l+ interval '1 day', u+ interval '1 day' from serie where i < (2*${duree})+1) select l, u from serie;"
	s "range_information record;"
	s "create_partition character varying;"
	s "BEGIN"
	s "open range_informations;"
	s "LOOP"
	s " FETCH range_informations INTO range_information;"
	s "EXIT WHEN NOT FOUND;"
	s "create_partition := 'create ${table_journalisation_mode} table if not exists ${1}_' || to_char(range_information.l,'YYYY_MM_DD') || '_' || to_char(range_information.u,'YYYY_MM_DD') || ' partition of ${1} for values from (''' || range_information.l || ''') to (''' ||  range_information.u || ''');';"
	s "EXECUTE (create_partition);"	
	s "END LOOP;"
	s "close range_informations;"
	s "END"
	s "\$BODY\$;"
}	

create_table_traqueur_sessions_actives(){		
	
	if [[ ${partitionnement} -eq 1 ]]; then
		s "create or replace temporary view vue_traqueur_sessions_actives as select current_timestamp as dtcol, *, 0::integer as iquery, query as tquery, 0::integer as itquery, null::tsvector as dquery,null::integer[] as blockers, 0::float as pourcentage_cpu, 0::bigint as mem, 0::bigint as swapped, null::jsonb as application_info "
		s "from pg_catalog.pg_stat_activity;"
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_sessions_actives (LIKE vue_traqueur_sessions_actives) partition by range(dtcol);"
	else
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_sessions_actives as select current_timestamp as dtcol, *, 0::integer as iquery, query as tquery, 0::integer as itquery, null::tsvector as dquery,null::integer[] as blockers, 0::float as pourcentage_cpu, 0::bigint as mem, 0::bigint as swapped, null::jsonb as application_info "
		s "from pg_catalog.pg_stat_activity with no data;"		
	fi	
	
	s "create index if not exists traqueur_sessions_actives_br1 on traqueur_sessions_actives using brin(dtcol) ${brin_autosummarize};"
	s "create index if not exists traqueur_sessions_actives_gs1 on traqueur_sessions_actives using gist(dquery);"
	s "create index if not exists traqueur_sessions_actives_gn1 on traqueur_sessions_actives using gin(application_info);"
				
	if [[ ${bloom_available} -eq 1 ]] && [[ ${partitionnement} -eq 0 ]]  || [[ ${bloom_available} -eq 1 ]]; then
		s "DO"
		s "\$BODY\$"
		s "DECLARE"
		s "create_index character varying;"
		s "BEGIN"
		s "SELECT 'create index if not exists traqueur_sessions_actives_bl1 on traqueur_sessions_actives using bloom(' || string_agg(column_name, ',') || ',iquery,tquery,itquery);' FROM information_schema.columns WHERE table_schema ='pg_catalog'  AND table_name = 'pg_stat_activity'  AND data_type in ('text', 'integer') INTO create_index;"
		s "EXECUTE (create_index);"
		s "END"
		s "\$BODY\$;"	
	fi	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_sessions_actives"
	fi	
	
}

create_table_traqueur_cluster_information(){	
	
	if [[ ${partitionnement} -eq 1 ]]; then
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_cluster_information(dtcol timestamp with time zone, cluster_hostname varchar, cluster_os_family varchar, cluster_postgres_version varchar, cluster_port varchar, cluster_archive_mode varchar, cluster_size bigint, cluster_pretty_size varchar, cluster_shared_buffers varchar, cluster_processes integer, cluster_databases varchar, cluster_comment varchar) partition by range(dtcol);"
	else
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_cluster_information(dtcol timestamp with time zone, cluster_hostname varchar, cluster_os_family varchar, cluster_postgres_version varchar, cluster_port varchar, cluster_archive_mode varchar, cluster_size bigint, cluster_pretty_size varchar, cluster_shared_buffers varchar, cluster_processes integer, cluster_databases varchar, cluster_comment varchar);"
	fi

	s "create index if not exists traqueur_cluster_information_br1 on traqueur_cluster_information using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_cluster_information"		
	fi	
}	

create_table_traqueur_cluster_stats(){
	
	if [[ ${partitionnement} -eq 1 ]]; then
		s "create or replace temporary view vue_traqueur_cluster_stats as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_stat_database;"
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_cluster_stats (LIKE vue_traqueur_cluster_stats) partition by range(dtcol);"
	else
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_cluster_stats as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_stat_database with no data;"	
	fi

	s "create index if not exists traqueur_cluster_stats_br1 on traqueur_cluster_stats using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_cluster_stats"		
	fi
}	

create_table_traqueur_io_stats(){
	
	if [[ ${partitionnement} -eq 1 ]]; then
		s "create or replace temporary view vue_traqueur_io_stats as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_stat_io;"
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_io_stats (LIKE vue_traqueur_io_stats) partition by range(dtcol);"
	else
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_io_stats as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_stat_io with no data;"	
	fi

	s "create index if not exists traqueur_io_stats_br1 on traqueur_io_stats using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_io_stats"		
	fi
}	

create_table_traqueur_bloqueurs_process(){
	
	if [[ ${partitionnement} -eq 1 ]]; then
		s "create or replace temporary view vue_traqueur_bloqueurs_process as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_stat_activity;"
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_bloqueurs_process (LIKE vue_traqueur_bloqueurs_process) partition by range(dtcol);"
	else
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_bloqueurs_process as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_stat_activity with no data;"
	fi

	s "create index if not exists traqueur_bloqueurs_process_br1 on traqueur_bloqueurs_process using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_bloqueurs_process"		
	fi
}

create_table_traqueur_bloqueurs_transactions(){
	
	if [[ ${partitionnement} -eq 1 ]]; then
		s "create or replace temporary view vue_traqueur_bloqueurs_transactions as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_prepared_xacts;"
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_bloqueurs_transactions (LIKE vue_traqueur_bloqueurs_transactions) partition by range(dtcol);"
	else 
		s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_bloqueurs_transactions as select current_timestamp as dtcol, * "
		s "from pg_catalog.pg_prepared_xacts with no data;"
	fi	

	s "create index if not exists traqueur_bloqueurs_transactions_br1 on traqueur_bloqueurs_transactions using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_bloqueurs_transactions"		
	fi
}

create_table_traqueur_bench(){
	
	s "create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_cluster_bench(dtcol timestamp with time zone, cluster_bench_cpu_ram varchar, cluster_bench_io varchar, cluster_bench_global_power varchar, cluster_bench_comment varchar);"
	s "create index if not exists traqueur_cluster_bench_br1 on traqueur_cluster_bench using brin(dtcol) ${brin_autosummarize};"	
}

create_table_traqueur_times(){
	
	create_function_traqueur_times		
	s "DO"
	s "\$BODY\$"
	s "DECLARE"
	s "create_table character varying;"
	s "BEGIN"
	s "with liste_colonnes as (select replace(replace(replace(regexp_replace(replace(pg_temp.traqueur_times(),'scputimes',''),'=(\d*\.?\d*)','','g'),',','_traqueur float, '),')','_traqueur float)'),'(','(dtcol timestamp with time zone, ') as colonnes) select 'create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_times'|| colonnes "
	if [[ ${partitionnement} -eq 1 ]]; then
		s "	|| ' partition by range(dtcol);' from liste_colonnes INTO create_table;"
	else 
		s "	|| ';' from liste_colonnes INTO create_table;"
	fi
	s "EXECUTE (create_table);"
	s "END"
	s "\$BODY\$;"	
	
	s "create index if not exists traqueur_times_br1 on traqueur_times using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_times"
	fi	
}		

create_table_traqueur_virtual_memory(){
	
	create_function_traqueur_virtual_memory		
	s "DO"
	s "\$BODY\$"
	s "DECLARE"
	s "create_table character varying;"
	s "BEGIN"
	s "with liste_colonnes as (select replace(replace(replace(regexp_replace(replace(pg_temp.traqueur_virtual_memory(),'svmem',''),'=(\d*\.?\d*)','','g'),',','_traqueur float, '),')','_traqueur float)'),'(','(dtcol timestamp with time zone, ') as colonnes) select 'create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_virtual_memory'|| colonnes "
	if [[ ${partitionnement} -eq 1 ]]; then
		s "	|| ' partition by range(dtcol);' from liste_colonnes INTO create_table;"
	else 
		s "	|| ';' from liste_colonnes INTO create_table;"
	fi
	s "EXECUTE (create_table);"
	s "END"
	s "\$BODY\$;"	
	
	s "create index if not exists traqueur_virtual_memory_br1 on traqueur_virtual_memory using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_virtual_memory"
	fi	
}		

create_table_traqueur_swap_memory(){
	
	create_function_traqueur_swap_memory		
	s "DO"
	s "\$BODY\$"
	s "DECLARE"
	s "create_table character varying;"
	s "BEGIN"
	s "with liste_colonnes as (select replace(replace(replace(regexp_replace(replace(pg_temp.traqueur_swap_memory(),'sswap',''),'=(\d*\.?\d*)','','g'),',','_traqueur float, '),')','_traqueur float)'),'(','(dtcol timestamp with time zone, ') as colonnes) select 'create ${table_persistence} ${table_journalisation_mode} table if not exists traqueur_swap_memory'|| colonnes "
	if [[ ${partitionnement} -eq 1 ]]; then
		s "	|| ' partition by range(dtcol);' from liste_colonnes INTO create_table;"
	else 
		s "	|| ';' from liste_colonnes INTO create_table;"
	fi
	s "EXECUTE (create_table);"
	s "END"
	s "\$BODY\$;"	
	
	s "create index if not exists traqueur_swap_memory_br1 on traqueur_swap_memory using brin(dtcol) ${brin_autosummarize};"
	
	if [[ ${partitionnement} -eq 1 ]]; then  
		add_partitions "traqueur_swap_memory"
	fi	
}		

if [[ ${stop_traqueur} -eq 1 ]]; then

	information "${info_026_stop_traqueur}"

	psql ${psql_connect_string} -c "select pg_terminate_backend(pid) from pg_stat_activity where datname = current_database() and query = 'call pg_temp.traqueur_collection();'" -v ON_ERROR_STOP=1 --quiet -X
	GLOBAL_RESULT="$?"
	
	for stop_traqueur_pid in ${TRAQUEUR_W}/traqueur.*; do
	    if [[ ${stop_traqueur_pid#*.} =~ ^[\-0-9]+$ ]]; then
	    	kill -0 ${stop_traqueur_pid#*.} 2>/dev/null
	    	if [[ $? -eq 1 ]]; then
			del_work_files ${stop_traqueur_pid#*.} 
	    	fi
	    fi	
	done 
	
	exit ${GLOBAL_RESULT}
fi

if [[ ${creation_user_monitor_interactif} -eq 1 ]]; then

	information "${info_022_creation_user_monitoring_interactif}"

	s "START TRANSACTION;"
	s "set search_path=${repository_schema}, ${TRAQUEUR_EXTENSIONS_SCHEMA};"

	s "DO"
	s "\$body\$"
	s "BEGIN"
   	s "IF NOT EXISTS ("
      	s "SELECT  "
      	s "FROM   pg_catalog.pg_user"
      	s "WHERE  usename = '${user_monitor_interactif}') THEN"
      	s "CREATE ROLE ${user_monitor_interactif};"
   	s "END IF;"
   	s "END"
   	s "\$body\$;"	

	s "GRANT connect, temporary ON DATABASE ${TRAQUEUR_DATABASE} to ${user_monitor_interactif};"   	
   	s "ALTER ROLE ${user_monitor_interactif} LOGIN;"
   	s "ALTER ROLE ${user_monitor_interactif} SET log_statement=\"none\";"
	s "ALTER ROLE ${user_monitor_interactif} PASSWORD '${TRAQUEUR_USER_MONITOR_PASSWORD}';"
	s "GRANT pg_monitor to ${user_monitor_interactif};"
	s " COMMIT;" 	

	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 --quiet -X
	GLOBAL_RESULT="$?"
	del_work_files ${process_number}
	exit ${GLOBAL_RESULT}

fi

if [[ ${charge_fichiers_plats} -eq 1 ]]; then

	information "${info_025_chargement_fichiers_plats}"

	s "start transaction;"
	s "set search_path=${repository_schema}, ${TRAQUEUR_EXTENSIONS_SCHEMA};"
	declare -i nombre_de_lignes_chargees=`wc -l <  "${dossier_fichiers_plats}//traqueur_sessions_actives.txt"`
	s "copy traqueur_sessions_actives from program 'head -n ${nombre_de_lignes_chargees} ${dossier_fichiers_plats}//traqueur_sessions_actives.txt';"
	s "commit;"

	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 --quiet -X
	GLOBAL_RESULT="$?"
	sed -i -e 1,"${nombre_de_lignes_chargees}d" "${dossier_fichiers_plats}//traqueur_sessions_actives.txt"
	del_work_files
	exit ${GLOBAL_RESULT}
fi

if [[ ${creation_repository_schema} -eq 1 ]]; then

	information "${info_020_creation_repository}" 

	s "START TRANSACTION;"
	s "set search_path=${repository_schema}, ${TRAQUEUR_EXTENSIONS_SCHEMA};"

	s "create schema if not exists ${repository_schema};"

	s "create schema if not exists ${TRAQUEUR_EXTENSIONS_SCHEMA};"
	if [[ ${bloom_available} -eq 1 ]]; then
		s "CREATE EXTENSION IF NOT EXISTS bloom CASCADE SCHEMA ${TRAQUEUR_EXTENSIONS_SCHEMA};"
	fi
	
	if [[ ! -z "${plpython_extension}" ]]; then
		s "CREATE EXTENSION IF NOT EXISTS ${plpython_extension};"
	fi
	
	create_table_traqueur_sessions_actives
	create_table_traqueur_cluster_information			
	create_table_traqueur_cluster_stats	
	if [[ ${postgres_version} -ge 160000 ]]; then
		create_table_traqueur_io_stats	
	fi		
	create_table_traqueur_bench
	create_table_traqueur_times
	create_table_virtual_memory
	create_table_swap_memory
	create_table_traqueur_bloqueurs_process
	create_table_traqueur_bloqueurs_transactions
	create_table_traqueur_tables_stats
	              
	s "DO"
	s "\$body\$"
	s "BEGIN"
   	s "IF NOT EXISTS ("
      	s "SELECT  "
      	s "FROM   pg_catalog.pg_user"
      	s "WHERE  usename = '${repository_user_insert_select}') THEN"
      	s "CREATE ROLE ${repository_user_insert_select} LOGIN;"
   	s "END IF;"
   	s "IF NOT EXISTS ("
      	s "SELECT  "
      	s "FROM   pg_catalog.pg_user"
      	s "WHERE  usename = '${repository_user_select}') THEN"
      	s "CREATE ROLE ${repository_user_select} LOGIN;"
   	s "END IF;"
	s "END"
	s "\$body\$;		"
	s "GRANT connect, temporary ON DATABASE ${TRAQUEUR_DATABASE} to ${repository_user_insert_select};"
	s "ALTER ROLE ${repository_user_insert_select} PASSWORD '${TRAQUEUR_REPOSITORY_USER_INSERT_SELECT_PASSWORD}';"
	s "ALTER ROLE ${repository_user_insert_select} set search_path=\"${repository_schema}\",\"${TRAQUEUR_EXTENSIONS_SCHEMA}\";"
	s "grant usage on schema ${repository_schema} to ${repository_user_insert_select};"
	s "grant insert, select on all tables in schema ${repository_schema} to ${repository_user_insert_select};"
	s "GRANT connect ON DATABASE ${TRAQUEUR_DATABASE} to ${repository_user_select};"		
	s "ALTER ROLE ${repository_user_select} PASSWORD '${TRAQUEUR_REPOSITORY_USER_SELECT_PASSWORD}';"
	s "ALTER ROLE ${repository_user_select} set search_path=\"${repository_schema}\",\"${TRAQUEUR_EXTENSIONS_SCHEMA}\";"
	s "grant usage on schema ${repository_schema} to ${repository_user_select};"
	s "grant select on all tables in schema ${repository_schema} to ${repository_user_select};"	
	s " COMMIT;" 	

	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 --quiet -X
	GLOBAL_RESULT="$?"
	del_work_files ${process_number}
	exit ${GLOBAL_RESULT}

fi	

if [[ ${destruction_repository_schema} -eq 1 ]]; then

	information "${info_021_destruction_repository}" 

	s "START TRANSACTION;"
	s "drop schema if exists ${repository_schema} cascade;"
	
	s "DO"
	s "\$body\$"
	s "BEGIN"
   	s "IF EXISTS ("
      	s "SELECT  "
      	s "FROM   pg_catalog.pg_user"
      	s "WHERE  usename = '${repository_user_insert_select}') THEN"
      	s "DROP OWNED BY ${repository_user_insert_select};"
      	s "DROP ROLE ${repository_user_insert_select};"
   	s "END IF;"
   	s "IF EXISTS ("
      	s "SELECT  "
      	s "FROM   pg_catalog.pg_user"
      	s "WHERE  usename = '${repository_user_select}') THEN"
      	s "DROP OWNED BY ${repository_user_select};"
      	s "DROP ROLE ${repository_user_select};"
   	s "END IF;"
   	s "END"
	s "\$body\$;		"
	
	s " COMMIT;" 	
	
	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 --quiet -X
	GLOBAL_RESULT="$?"
	del_work_files ${process_number}
	exit ${GLOBAL_RESULT}
fi

if [[ ${rapport} -eq 1 ]]; then
	space_check "${TRAQUEUR_W}" 100
	if [[ $? -eq 1 ]]; then
		error "${error_008_espace} $TRAQUEUR_W"
		error "${error_009_espace} 100k"
		error "${error_010_espace}TRAQUEUR_W"
		exit 1
	elif [[ $? -eq 2 ]]; then		
		warning "${warning_002_espace}TRAQUEUR_W"
	fi
	information "${info_006_rapport}" 
	if [[ -z ${TRAQUEUR_RAPPORT_DEBUT+x} ]]; then
		interactive "${interactive_001_debut_rapport}"
		declare TRAQUEUR_RAPPORT_DEBUT
		read TRAQUEUR_RAPPORT_DEBUT
		if [[ ${TRAQUEUR_RAPPORT_DEBUT} == "" ]]; then
			TRAQUEUR_RAPPORT_DEBUT="current_timestamp - interval '15 minutes'"						
		fi
	fi
	if [[ -z ${TRAQUEUR_RAPPORT_FIN+x} ]]; then
		interactive "${interactive_002_fin_rapport}"
		declare TRAQUEUR_RAPPORT_FIN
		read TRAQUEUR_RAPPORT_FIN
		if [[ ${TRAQUEUR_RAPPORT_FIN} == "" ]]; then
			TRAQUEUR_RAPPORT_FIN="current_timestamp"						
		fi
	fi
	if [[ -z ${TRAQUEUR_RAPPORT_TOP_N+x} ]]; then
		interactive "${interactive_003_top_n_rapport}"
		declare -i TRAQUEUR_RAPPORT_TOP_N
		read TRAQUEUR_RAPPORT_TOP_N
		if [[ ${TRAQUEUR_RAPPORT_TOP_N} -eq 0 ]]; then
			TRAQUEUR_RAPPORT_TOP_N=5
		fi
	fi
	if [[ -z ${TRAQUEUR_RAPPORT_FILTRE+x} ]]; then
		interactive "${interactive_004_filtre_rapport}"
		declare TRAQUEUR_RAPPORT_FILTRE
		read TRAQUEUR_RAPPORT_FILTRE
		if [[ ${TRAQUEUR_RAPPORT_FILTRE} == "" ]]; then			
				TRAQUEUR_RAPPORT_FILTRE="application_name <> 'traqueur' and backend_type <> 'autovacuum worker' and backend_type <> 'walsender'"				
		fi
	fi
	if [[ -z ${TRAQUEUR_RAPPORT_FORMAT+x} ]]; then
		interactive "${interactive_005_format_rapport}"
		declare TRAQUEUR_RAPPORT_FORMAT
		read TRAQUEUR_RAPPORT_FORMAT
		if [[ ${TRAQUEUR_RAPPORT_FORMAT} == "" ]]; then
			TRAQUEUR_RAPPORT_FORMAT="aligned"
		fi
	fi
	if [[ -z ${TRAQUEUR_RAPPORT_NOM+x} ]]; then
		interactive "${interactive_006_nom_rapport}"
		declare TRAQUEUR_RAPPORT_NOM
		read TRAQUEUR_RAPPORT_NOM
		if [[ ${TRAQUEUR_RAPPORT_NOM} == "" ]]; then
			if [[ ${TRAQUEUR_RAPPORT_FORMAT} == "aligned" ]]; then
				TRAQUEUR_RAPPORT_NOM="${TRAQUEUR_W}/rapport_traqueur_${process_number}.txt"
			else
				TRAQUEUR_RAPPORT_NOM="${TRAQUEUR_W}/rapport_traqueur_${process_number}.htm"
			fi
		fi
	fi
	s "\o /dev/null"
	s "set search_path=${TRAQUEUR_LOCAL_SCHEMA};"
	s "set client_min_messages to WARNING;"
	
	if [[ ${superuser} == "t" ]] && [[ ${psutil} -eq 1 ]]; then
		s "CREATE EXTENSION IF NOT EXISTS ${plpython_extension};"
		create_function_traqueur_system	
		create_function_traqueur_hostname
	fi	
	
	
	if [[ ${psutil} -eq 1 ]]; then
		create_function_maxsumbydtcol_sfunc
		create_function_maxsumbydtcol_finalfunc
		create_aggregate_maxsumbydtcol
	fi	
	
	s "DO"
	s "\$body\$"
	s "BEGIN"
   	s "IF (SELECT usesuper FROM pg_user WHERE usename = CURRENT_USER) THEN"
    	s "set log_statement=\"none\";"
   	s "END IF;"
	s "END"
	s "\$body\$;"	
	
	s "\pset footer off"
	s "\pset format ${TRAQUEUR_RAPPORT_FORMAT}"
	s "\o"
	s "\echo        ${report_000_titre}        "
	s "\echo "
	if [[ ${superuser} == "t" ]] && [[ ${psutil} -eq 1 ]];  then
		s "select pg_temp.traqueur_hostname() as \"${report_001_serveur}\";"
	else
		s "select cluster_hostname as \"${report_001_serveur}\" from traqueur_cluster_information where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} fetch first 1 row only;" 
	fi 		
	
	s "select to_char(min(dtcol),'DD/MM/YYYY HH24:MI:SS') as \"${report_002_borne_inferieure}\", to_char(max(dtcol),'DD/MM/YYYY HH24:MI:SS') as \"${report_003_borne_superieure}\" from traqueur_sessions_actives where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN};"
	
	if [[ ${psutil} -eq 1 ]]; then
	
		s "select round(elapsed::numeric,2) as \"${report_023_elapsed}\",  round(dbtime::numeric,2) as \"${report_024_dbtime}\", round((dbtime/elapsed)::numeric,2) as \"${report_025_avg_active_sessions}\" from"
		s "(select extract (epoch from (max(dtcol) filter (where datid is null and pid is null) - min(dtcol) filter (where datid is null and pid is null))) as elapsed, ((extract (epoch from (max(dtcol) filter (where datid is null and pid is null))) - extract(epoch from (min(dtcol) filter (where datid is null and pid is null))))*count(1) filter (where (datid is not null or pid is not null) and (${TRAQUEUR_RAPPORT_FILTRE})))/(count(1) filter (where datid is null and pid is null)) as dbtime from traqueur_sessions_actives where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN}) ed;"
		
		s "\echo - ${report_004_infos_systeme} -"
		s "select round(avg(pourcentage_cpu)) as \"${report_005_charge_CPU}\" from traqueur_sessions_actives where pid is null and dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN};"
		s "with vals_deb as (select * from traqueur_times where dtcol = (select min(dtcol) from traqueur_times where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN})), "
		s "vals_fin as (select * from traqueur_times where dtcol = (select max(dtcol) from traqueur_times where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN}))"
		s "select round(vals_fin.user_traqueur - vals_deb.user_traqueur) as ${report_006_temps_CPU_user}, "
		s "round(vals_fin.system_traqueur - vals_deb.system_traqueur) as ${report_007_temps_CPU_systeme}, "
		s "round(vals_fin.idle_traqueur - vals_deb.idle_traqueur) as ${report_008_temps_CPU_idle} "
		if [[ ${superuser} == "t" ]] && [[ ${psutil} -eq 1 ]]; then
			s ", CASE when upper(pg_temp.traqueur_system()) like '%LINUX%'"		
		else
			s ", CASE when (select upper(cluster_os_family) from traqueur_cluster_information where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} fetch first 1 row only) like '%LINUX%' 			   "
		fi
		s "then round(vals_fin.iowait_traqueur - vals_deb.iowait_traqueur) ELSE null END AS ${report_009_temps_io}"	
		s "from vals_deb, vals_fin;"
	fi	
	
	if [[ ${psutil} -eq 1 ]]; then
		
		s "select round(max(total_traqueur)/1024/1024) as \"${report_034_total_memory}\" from traqueur_virtual_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
		s "select round(min(percent_traqueur)) as \"${report_035_min_memory_occupation}\" from traqueur_virtual_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
		s "select round(avg(percent_traqueur)) as \"${report_036_avg_memory_occupation}\" from traqueur_virtual_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
		s "select round(max(percent_traqueur)) as \"${report_037_max_memory_occupation}\" from traqueur_virtual_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"

		s "select round(max(total_traqueur)/1024/1024) as \"${report_038_total_swap}\" from traqueur_swap_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
		s "select round(min(percent_traqueur)) as \"${report_039_min_swap_occupation}\" from traqueur_swap_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
		s "select round(avg(percent_traqueur)) as \"${report_040_avg_swap_occupation}\" from traqueur_swap_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
		s "select round(max(percent_traqueur)) as \"${report_041_max_swap_occupation}\" from traqueur_swap_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} ;"
	
		s "with vals_sw_deb as (select * from traqueur_swap_memory where dtcol = (select min(dtcol) from traqueur_swap_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN})), "
		s "vals_sw_fin as (select * from traqueur_swap_memory where dtcol = (select max(dtcol) from traqueur_swap_memory where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN})) "
		s "select pg_size_pretty((vals_sw_fin.sin_traqueur - vals_sw_deb.sin_traqueur + vals_sw_fin.sout_traqueur - vals_sw_deb.sout_traqueur)::bigint) as \"${report_042_swapped_memory}\" "
		s "from vals_sw_deb, vals_sw_fin;"
	fi

	if [[ ${pg_latence} -eq 1 ]]; then
		s "\echo - ${report_027_latence} -"
		s "with haut as (select dtcol, context, read_time, reads, write_time, writes, writeback_time, writebacks, extends, extend_time, fsync_time, fsyncs, evictions, stats_reset from traqueur_io_stats where dtcol = (select max(dtcol) from traqueur_io_stats where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} )), bas as (select dtcol, context, read_time, reads, write_time, writes, writeback_time, writebacks, extends, extend_time, fsync_time, fsyncs, evictions, stats_reset from traqueur_io_stats where dtcol = (select min(dtcol) from traqueur_io_stats where dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN})) select haut.context \"Contexte\", case when (sum(haut.reads)-sum(bas.reads)) <> 0 then round(((sum(haut.read_time)-sum(bas.read_time))/(sum(haut.reads)-sum(bas.reads)))::numeric,2) else null end \"${report_028_latence_lectures}\", case when (sum(haut.writes)-sum(bas.writes)) <> 0 then round(((sum(haut.write_time)-sum(bas.write_time))/(sum(haut.writes)-sum(bas.writes)))::numeric,2) else null end \"${report_029_latence_ecritures}\", case when (sum(haut.writebacks)-sum(bas.writebacks)) <> 0 then round(((sum(haut.writeback_time)-sum(bas.writeback_time))/(sum(haut.writebacks)-sum(bas.writebacks)))::numeric,2) else null end \"${report_030_latence_ecritures_permanentes}\", case when (sum(haut.extends)-sum(bas.extends)) <> 0 then round(((sum(haut.extend_time)-sum(bas.extend_time))/(sum(haut.extends)-sum(bas.extends)))::numeric,2) else null end \"${report_031_latence_extensions_fichiers}\", case when (sum(haut.fsyncs)-sum(bas.fsyncs)) <> 0 then round(((sum(haut.fsync_time)-sum(bas.fsync_time))/(sum(haut.fsyncs)-sum(bas.fsyncs)))::numeric,2) else null end \"${report_032_latence_fsyncs}\", sum(haut.evictions)-sum(bas.evictions) \"${report_033_evictions}\" from haut join bas on (haut.context = bas.context) where haut.stats_reset = bas.stats_reset group by haut.context order by haut.context asc;"
	fi
	
	s "\x"
	s "\echo - Top ${TRAQUEUR_RAPPORT_TOP_N} ${report_010_evenements} -"	
	s "select wait_event_type as \"${report_012_type_evenement}\", count(*) as \"${report_013_nombre_de_detections}\""
	s "from traqueur_sessions_actives where (pid is not null or datid is not null) and dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} and (${TRAQUEUR_RAPPORT_FILTRE}) group by wait_event_type order by \"${report_013_nombre_de_detections}\" desc fetch first 5 rows only;"		
	
	s "\echo - Top ${TRAQUEUR_RAPPORT_TOP_N} ${report_011_requetes} -"
	s "select datname as \"${report_014_base_de_donnees}\", usename as \"${report_015_utilisateur}\", to_hex(coalesce(itquery, iquery)) as \"${report_016_identifiant_requete}\", coalesce(tquery, query) as \"${report_017_requete}\", application_name as \"${report_018_application}\", count(*) as \"${report_013_nombre_de_detections}\""
	if [[ ${postgres_version} -ge 130000 ]]; then		
		s ", count(*) filter (where leader_pid is null) as \"${report_026_nombre_detections_nonparalleles}\""
	fi
	s ", count(distinct(query_start)) as \"${report_019_nombre_executions_distinctes}\" "
	if [[ ${psutil} -eq 1 ]]; then
		s ", greatest(round(100-avg(pourcentage_cpu)),0) as \"${report_020_pourcentage_moyen_non_CPU}\", pg_size_pretty(pg_temp.maxsumbydtcol(row_to_json(row(dtcol, mem)) order by dtcol)) as \"${report_021_max_conso_memoire}\", pg_size_pretty(pg_temp.maxsumbydtcol(row_to_json(row(dtcol, swapped)) order by dtcol)) as \"${report_022_max_conso_swap}\""
	fi
	s "from traqueur_sessions_actives where (pid is not null or datid is not null) and dtcol >= ${TRAQUEUR_RAPPORT_DEBUT} AND dtcol <= ${TRAQUEUR_RAPPORT_FIN} and (${TRAQUEUR_RAPPORT_FILTRE}) group by datname, usename, to_hex(coalesce(itquery, iquery)), coalesce(tquery, query), application_name order by \"${report_013_nombre_de_detections}\" desc fetch first ${TRAQUEUR_RAPPORT_TOP_N} rows only;"
	
	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number} -v ON_ERROR_STOP=1 --quiet -X > ${TRAQUEUR_RAPPORT_NOM}
	GLOBAL_RESULT="$?"
	del_work_files ${process_number}
	exit ${GLOBAL_RESULT}
fi

if [[ ${change_journalisation_mode} -eq 1 ]]; then
	space_check "${TRAQUEUR_W}" 100
	if [[ $? -eq 1 ]]; then
		error "${error_008_espace} $TRAQUEUR_W"
		error "${error_009_espace} 100k"
		error "${error_010_espace}TRAQUEUR_W"
		exit 1
	elif [[ $? -eq 2 ]]; then		
		warning "${warning_002_espace}TRAQUEUR_W"
	fi	
	information "${info_009_change_journalisation}" 
	s "set search_path=${TRAQUEUR_LOCAL_SCHEMA},${TRAQUEUR_EXTENSIONS_SCHEMA};"
    s "START TRANSACTION;"
    s "DO "
    s "\$\$"
    s "DECLARE"
    s "traqueur_tables_partitions_list cursor for SELECT c.oid,"
    s "'alter table if exists ' ||  c.relname || ' set ${table_journalisation_mode};' as alter_traqueur_table_partition"
    s "FROM pg_catalog.pg_class c"
    s "JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
    s "WHERE "
    s "c.relname ~ '^(traqueur_*)'"
    s "AND pg_catalog.pg_table_is_visible(c.oid)"
    s "AND n.nspname = current_schema"
    s "AND c.relkind in ('r','p');"
    s "traqueur_table_partition record;"
    s "alter_traqueur_table_partition_ddl character varying;"
    s "BEGIN"
    s "open traqueur_tables_partitions_list;"
    s "LOOP"
    s " FETCH traqueur_tables_partitions_list INTO traqueur_table_partition;"
    s "EXIT WHEN NOT FOUND;"
    s "alter_traqueur_table_partition_ddl := traqueur_table_partition.alter_traqueur_table_partition;"
    s "EXECUTE (alter_traqueur_table_partition_ddl);"
    s "END LOOP;"
    s "close traqueur_tables_partitions_list;"
    s "END"
    s "\$\$;        "
    s "COMMIT;"

	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 -X
	let GLOBAL_RESULT=GLOBAL_RESULT+$?
	del_work_files ${process_number}
	exit ${GLOBAL_RESULT}
fi

truncate_delete(){
	s "DO "
	s "\$\$"
	s "DECLARE"
	s "nb_lignes_supprimees bigint;	"
	s "BEGIN"	
	s "IF EXISTS ("	
	s "	SELECT 1"	
	s "	FROM   "	
	s "	pg_catalog.pg_class c"	
	s "	JOIN   "	
 	s "	pg_catalog.pg_namespace n ON n.oid = c.relnamespace"	
      	s "	WHERE  n.nspname = current_schema"	
      	s "	AND    c.relname = '${1}'"	
      	s "	AND    c.relkind in ('r', 'p'))     "	     
	s "THEN"	
	if [[ ${fenetre_menage} -eq 0 ]]; then
		s "	truncate table ${1};"   	
	else
		s "	delete from ${1} where dtcol < current_timestamp - interval '${fenetre_menage} days';" 
	fi 	
	if [[ ${verbosite} -ge 3 ]]; then
		if [[ ${fenetre_menage} -ne 0 ]]; then
			s "	GET DIAGNOSTICS nb_lignes_supprimees = ROW_COUNT;"	
			s "	RAISE NOTICE '${info_012_suppression_lignes}, ${1}', nb_lignes_supprimees;"
		fi	
	fi
	if [[ ${verbosite} -ge 2 ]] && [[ ${2} == "warning" ]]; then
		s "ELSE"	
		s "	RAISE ${2} '${warning_004_table_introuvable} : ${1}';"	
	fi
	if [[ ${verbosite} -ge 3 ]] && [[ ${2} == "notice" ]]; then
		s "ELSE"	
		s "	RAISE ${2} '${info_011_table_introuvable} : ${1}';"	
	fi
	s "END IF;"
	s "END"
	s "\$\$;"
}			

if [[ ${menage} -eq 1 ]]; then
	space_check "${TRAQUEUR_W}" 100
	if [[ $? -eq 1 ]]; then
		error "${error_008_espace} $TRAQUEUR_W"
		error "${error_009_espace} 100k"
		error "${error_010_espace}TRAQUEUR_W"
		exit 1
	elif [[ $? -eq 2 ]]; then		
		warning "${warning_002_espace}TRAQUEUR_W"
	fi
	information "${info_007_menage}" 
	s "set search_path=${TRAQUEUR_LOCAL_SCHEMA},${TRAQUEUR_EXTENSIONS_SCHEMA};"
	s "START TRANSACTION;"		
	if [[ ${partitionnement} -eq 1 ]]; then
		s "DO "	
		s "\$\$"
		s "DECLARE"
		s "traqueur_partitions_list cursor for SELECT f.oid,"
       		s "'drop table if exists ' ||  f.relname || ';' as drop_partition"
		s "FROM pg_catalog.pg_class c"
		s "JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
        		s "JOIN pg_catalog.pg_inherits i ON c.oid = i.inhparent"
		s "JOIN pg_catalog.pg_class f ON i.inhrelid = f.oid"
		s "WHERE "
		s "c.relname ~ '^(traqueur_*)'"
		s "AND pg_catalog.pg_table_is_visible(c.oid)"
		s "AND n.nspname = current_schema"
		s "AND f.relkind = 'r'"
		s "AND (substring((string_to_array(pg_catalog.pg_get_expr(f.relpartbound, f.oid, true), 'TO'))[2] FROM '[0-9\-]+'))::timestamp <=  date_trunc('day', current_timestamp) - interval '${fenetre_menage} days' ;"
		s "traqueur_partition record;"
		s "drop_partition_table character varying;"
		s "BEGIN"
		s "open traqueur_partitions_list;"
		s "LOOP"
		s " FETCH traqueur_partitions_list INTO traqueur_partition;"
		s "EXIT WHEN NOT FOUND;"
		s " drop_partition_table := traqueur_partition.drop_partition;"
		s "EXECUTE (drop_partition_table);"
		s "END LOOP;"
		s "close traqueur_partitions_list;"
		s "END"
		s "\$\$;	"	
	else
		truncate_delete "traqueur_sessions_actives" "warning"	
		truncate_delete "traqueur_cluster_information" "notice"
		truncate_delete "traqueur_cluster_stats" "notice"
		if [[ ${postgres_version} -ge 160000 ]]; then
			truncate_delete "traqueur_io_stats" "notice"
		fi	
		truncate_delete "traqueur_times" "notice"
		truncate_delete "traqueur_bloqueurs_process" "notice"
		truncate_delete "traqueur_bloqueurs_transactions" "notice"
	fi
	s "COMMIT;"
	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 -X
	let GLOBAL_RESULT=GLOBAL_RESULT+$?
	del_work_files ${process_number}
fi

if [[ ${raz} -eq 1 ]]; then
	space_check "${TRAQUEUR_W}" 100
	if [[ $? -eq 1 ]]; then
		error "${error_008_espace} $TRAQUEUR_W"
		error "${error_009_espace} 100k"
		error "${error_010_espace}TRAQUEUR_W"
		exit 1
	elif [[ $? -eq 2 ]]; then		
		warning "${warning_002_espace}TRAQUEUR_W"
	fi
	s "set search_path=${TRAQUEUR_LOCAL_SCHEMA},${TRAQUEUR_EXTENSIONS_SCHEMA};"
	s "\o /dev/null"
	s "\set AUTOCOMMIT on"
    	s "\o"
	s "START TRANSACTION;"
	s "drop schema if exists ${TRAQUEUR_LOCAL_SCHEMA} cascade;"
	s "COMMIT;"
	psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 -X
	let GLOBAL_RESULT=GLOBAL_RESULT+$?
	del_work_files ${process_number}
	exit ${GLOBAL_RESULT}
fi

information "${info_001_preparation_traque}"

if [[ ${mode_batch} -eq 1 ]]; then
	declare -i pg_sleep_intervalle_ms=1000*${pg_sleep_intervalle}
else
	declare -i pg_sleep_intervalle_ms=10*${pg_sleep_intervalle}
fi

declare -i iterations
if [[ ${duree} -eq 0 ]]; then
	let iterations=1
else
	if [[ ${mode_batch} -eq 1 ]]; then
		let iterations=$(((86400*${duree})/${pg_sleep_intervalle}))
	elif [[ ${pg_sleep_intervalle_ms} -eq 0 ]]; then
		let iterations=$((1000*${duree}))
	else	
		let iterations=$(((100*${duree})/${pg_sleep_intervalle}))
		
	fi
fi	
	
space_check "${TRAQUEUR_W}" 100

if [[ $? -eq 1 ]]; then
	error "${error_008_espace} $TRAQUEUR_W"
	error "${error_009_espace} $((iterations / 5))k"
	error "${error_010_espace}TRAQUEUR_W"
	exit 1
elif [[ $? -eq 2 ]]; then		
	warning "${warning_002_espace}TRAQUEUR_W"
fi

if [[ ${mode_batch} -eq 0 ]]; then  
   	table_journalisation_mode=""
fi

s "\o /dev/null"
s "\set AUTOCOMMIT on"
s "set client_min_messages to WARNING;"

s "DO"
s "\$body\$"
s "BEGIN"
s "IF (SELECT usesuper FROM pg_user WHERE usename = CURRENT_USER) THEN"
s "set log_statement=\"none\";"
s "END IF;"
s "END"
s "\$body\$;"
		
s "set work_mem=\"32MB\";"
s "set statement_timeout=0;"
spf "\\\\timing ${psql_timing} \n"

s "set search_path=${TRAQUEUR_LOCAL_SCHEMA},${TRAQUEUR_EXTENSIONS_SCHEMA};"

if [[ ${lecture_seule} -eq 0 ]]; then
s "START TRANSACTION;"


if [[ ${mode_batch} -eq 1 ]]; then 
	if [[ ${superuser} == "t" ]]; then
		s "create schema if not exists ${TRAQUEUR_LOCAL_SCHEMA};"
	fi
fi

if [[ ${stockage_distant} -eq 1 ]] && [[ ${partitionnement} -eq 1 ]]; then  
	warning "${warning_007_partitionnement_distant}"
fi

if [[ ${stockage_distant} -eq 1 ]]; then  
	if [[ ${superuser} == "t" ]]; then
		s "create schema if not exists ${TRAQUEUR_EXTENSIONS_SCHEMA};"
		s "CREATE EXTENSION IF NOT EXISTS postgres_fdw CASCADE SCHEMA ${TRAQUEUR_EXTENSIONS_SCHEMA};"
		s "DROP SERVER IF EXISTS traqueur_repository CASCADE;"
		s "CREATE SERVER traqueur_repository FOREIGN DATA WRAPPER postgres_fdw OPTIONS (${repository_connect_informations});"
		s "CREATE USER MAPPING FOR CURRENT_USER SERVER traqueur_repository OPTIONS (user '${repository_user_insert_select}'"
		if [[ ${pas_de_mot_de_passe_user_mapping} -eq 1 ]]; then  
			s ");"	
		else
			s ", password '${TRAQUEUR_REPOSITORY_USER_INSERT_SELECT_PASSWORD}');"	
		fi
		s "IMPORT FOREIGN SCHEMA ${repository_schema} FROM SERVER traqueur_repository INTO ${TRAQUEUR_LOCAL_SCHEMA};"	
	fi
fi

if [[ ${superuser} == "t" ]]; then
	s "create schema if not exists ${TRAQUEUR_EXTENSIONS_SCHEMA};"
	if [[ ${bloom_available} -eq 1 ]]; then
		s "CREATE EXTENSION IF NOT EXISTS bloom CASCADE SCHEMA ${TRAQUEUR_EXTENSIONS_SCHEMA};"
	fi
fi

if [[ ${stockage_distant} -eq 0 ]]; then  
	create_table_traqueur_sessions_actives	
	if [[ ${postgres_version} -ge 160000 ]]; then
		create_table_traqueur_io_stats	
	fi		
fi	

if [[ ${normalise} -eq 1 ]]; then
	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_normalize_query(IN TEXT, OUT TEXT) AS \$body\$"
	s "  SELECT"
	s "    regexp_replace(regexp_replace(regexp_replace(regexp_replace("
	s "    regexp_replace(regexp_replace(regexp_replace(regexp_replace("
	s "    lower(\$1),"
	s "    '\s+',                          ' ',           'g'   ), "           
	s "    \$\$\\\\'\$\$,                        '',            'g'   ),"
	s "    \$\$'[^']*'\$\$,                    \$\$''\$\$,        'g'   ),"
	s "    \$\$''('')+\$\$,                    \$\$''\$\$,        'g'   ),"
	s "    '=\s*NULL',                     '=0',          'g'   ),"
	s "    '([^a-z_$-])-?([0-9]+)',        '\1'||'0',     'g'   ),"
	s "    '([^a-z_$-])0x[0-9a-f]{1,10}',  '\1'||'0x',    'g'   ),"
	s "    'in\s*\([''0x,\s]*\)',          'in (...)',    'g'   )"
	s "  ;"
	s "\$body\$"
	s "LANGUAGE SQL;"
	
fi

if [[ ! -z "${plpython_extension}" ]] && [[ ${general_information} -eq 1 ]] || [[ ${psutil} -eq 1 ]] && [[ ${superuser} == "t" ]]; then
	s "CREATE EXTENSION IF NOT EXISTS ${plpython_extension};"	
	create_function_traqueur_system
fi

if [[ ${general_information} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
	create_function_traqueur_hostname	
	if [[ ${stockage_distant} -eq 0 ]]; then  
		create_table_traqueur_cluster_information
		create_table_traqueur_cluster_stats		
		create_table_traqueur_bench
	fi	
fi

if [[ ${bloqueurs_information} -eq 1 ]] && [[ ${mode_batch} -eq 1 ]]; then
	create_table_traqueur_bloqueurs_process
	create_table_traqueur_bloqueurs_transactions
fi
	
if [[ ${psutil} -eq 1 ]]; then

	create_function_traqueur_times
	create_function_traqueur_virtual_memory
	create_function_traqueur_swap_memory
	
	if [[ ${stockage_distant} -eq 0 ]]; then  
		create_table_traqueur_times
		create_table_traqueur_virtual_memory
		create_table_traqueur_swap_memory
	fi
	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_insert_times() RETURNS VOID AS"
	s "\$BODY\$"
	s "DECLARE"
	s "insert_times character varying;"
	s "BEGIN"
	s "with liste_valeurs as (select replace(regexp_replace(pg_temp.traqueur_times(),'[a-z+=_]','','g'),'(', '(clock_timestamp(), ') as valeurs) select 'insert into traqueur_times values'|| valeurs || ';' from liste_valeurs INTO insert_times;"
	s "EXECUTE (insert_times);"
	s "END"
	s "\$BODY\$"
	s "LANGUAGE plpgsql;"
	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_insert_virtual_memory() RETURNS VOID AS"
	s "\$BODY\$"
	s "DECLARE"
	s "insert_virtual_memory character varying;"
	s "BEGIN"
	s "with liste_valeurs as (select replace(regexp_replace(pg_temp.traqueur_virtual_memory(),'[a-z+=_]','','g'),'(', '(clock_timestamp(), ') as valeurs) select 'insert into traqueur_virtual_memory values'|| valeurs || ';' from liste_valeurs INTO insert_virtual_memory;"
	s "EXECUTE (insert_virtual_memory);"
	s "END"
	s "\$BODY\$"
	s "LANGUAGE plpgsql;"
	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_insert_swap_memory() RETURNS VOID AS"
	s "\$BODY\$"
	s "DECLARE"
	s "insert_swap_memory character varying;"
	s "BEGIN"
	s "with liste_valeurs as (select replace(regexp_replace(pg_temp.traqueur_swap_memory(),'[a-z+=_]','','g'),'(', '(clock_timestamp(), ') as valeurs) select 'insert into traqueur_swap_memory values'|| valeurs || ';' from liste_valeurs INTO insert_swap_memory;"
	s "EXECUTE (insert_swap_memory);"
	s "END"
	s "\$BODY\$"
	s "LANGUAGE plpgsql;"
	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_cpu_pid (pids integer[])"
	s "RETURNS json"
	s "AS \$\$"
	s "import psutil"
	s "import json"
	s "import time    "
	s "if pids: "
	s "	for i in pids:	"
	s "		try:	"
	s "			globals()[i] = psutil.Process(i)"
	s "			globals()[i].cpu_percent(0)"
	s "		except:	"
	s "			v = 0"	
	s "pids_pc = []"
	s "g = psutil.cpu_percent( 0.1 )"
	s "if pids: "
	s "	for i in pids:	"
	s "		try:	"
	s "			v = globals()[i].cpu_percent(0)	"
	s "		except:	"
	s "			v = 0"
	s "		pids_pc.append({'pid':i, 'pc':v})"
	s "pids_pc.append({'pid':0, 'pc':g})"
	s "return json.dumps(pids_pc)   "
	s "\$\$ LANGUAGE ${plpython_extension}; "
	
	s "CREATE OR REPLACE FUNCTION pg_temp.traqueur_mem_pid(pids integer[])"
 	s "RETURNS json"
	s "AS \$\$"
	s "import psutil"
	s "import json"
	s "pids_mem = []"
	s "if pids:"
	s "	for i in pids:"
	s "		try:"
	s "			globals()[i] = psutil.Process(i).memory_full_info()"
	s "			uss = globals()[i].uss"
	s "			swap = globals()[i].swap"
	s "		except:"
	s "			uss = 0"
	s "			swap = 0"
	s "		pids_mem.append({'pid':i, 'uss':uss, 'swap':swap})"
	s "return json.dumps(pids_mem)"
	s "\$\$ LANGUAGE ${plpython_extension}; "
	
fi

s " COMMIT;" 

if [[ ${psutil} -eq 1 ]] && [[ ${mode_batch} -eq 0 ]]; then
	s "START TRANSACTION;"
	s "select pg_temp.traqueur_insert_times();"
	s "select pg_temp.traqueur_insert_virtual_memory();"
	s "select pg_temp.traqueur_insert_swap_memory();"
	s "COMMIT;"
fi	

fi

if [[ ${mode_batch} -eq 1 ]]; then
	if [[ ${lecture_seule} -eq 0 ]]; then
		create_procedure_function_traqueur_collection "1"
		s "call pg_temp.traqueur_collection(${max_collections_infructueuses});" 		
	else	
		anonymous_traqueur_collection	
	fi
elif [[ ${mode_batch} -eq 0 ]]; then
	create_procedure_function_traqueur_collection "2"
	s "START TRANSACTION;"
	s "select pg_temp.traqueur_collection(${max_collections_infructueuses});" 
	s "COMMIT;"
fi		

if [[ ${psutil} -eq 1 ]] && [[ ${mode_batch} -eq 0 ]]; then
	s "START TRANSACTION;"
	s "select pg_temp.traqueur_insert_times();"
	s "select pg_temp.traqueur_insert_virtual_memory();"
	s "select pg_temp.traqueur_insert_swap_memory();"
	s "COMMIT;"
fi	

if [[ ${mode_batch} -eq 0 ]]; then 

	if [[ ${psutil} -eq 1 ]]; then		
			create_function_maxsumbydtcol_sfunc
			create_function_maxsumbydtcol_finalfunc
			create_aggregate_maxsumbydtcol
	fi
			
	declare -i nb_commas
	declare -i column_group_by_number
	declare columns_group_by_list	
	declare -i columns_list_by_default=0
	if [[ ${columns_list_number} -eq 0 ]]; then
		columns_list_by_default=1
		columns_list_number=1
	fi		
	
	for ((i=0; i < ${columns_list_number}; i++));
	do
		nb_commas=`echo "${columns_list[$i]}" | sed -e ':again;' -e '$!N;$!b again;' -e ':b' -e '; s/([^()]*)//g; t b' |  awk -F, '{ print NF - 1 }'`
		let "nb_columns_to_group=${nb_commas}+1"
		columns_group_by_list="3"
		column_group_by_number=3
		for ((j=2;j<=${nb_columns_to_group};j++)); do	
			let column_group_by_number=${column_group_by_number}+1
			columns_group_by_list="${columns_group_by_list},${column_group_by_number}"
		done
					
		if [[ ${psutil} -eq 1 ]]; then	
			columns_list[$i]="${columns_list[$i]}, greatest(round(100-avg(pourcentage_cpu)),0) as \"non_cpu_pc (avg)\", pg_size_pretty(pg_temp.maxsumbydtcol(row_to_json(row(dtcol, mem)) order by dtcol)) as \"mem (max sum)\", pg_size_pretty(pg_temp.maxsumbydtcol(row_to_json(row(dtcol, swapped)) order by dtcol)) as \"swap (max sum)\"" 		
		fi

		if [[ ${extended_psql_display} -eq 1 ]]; then
			s "\x on"	
		fi
		s "\o"
		s "select round(count(*)::double precision/"
		if [[ ${stop_collection} -eq 1 ]]; then
			s "(select valeur from iterations_reelles)"	
		else	
			s "${iterations}"	
		fi		
		s "*100) as busy_pc, count(distinct(query_start)) ||  ' / ' || count(query_start)  as distinct_exe,${columns_list[$i]} from traqueur_sessions_actives where pid is not null group by ${columns_group_by_list} order by busy_pc desc;"
		if [[ ${columns_list_by_default} -eq 1 ]]; then
			break
		fi		
	done	
fi

if [[ ${mode_batch} -eq 0 ]] && [[ ${psutil} -eq 1 ]]; then
	s "select round(avg(pourcentage_cpu)) as \"${report_005_charge_CPU}\" from traqueur_sessions_actives where pid is null;"
	s "with vals_deb as (select * from traqueur_times where dtcol = (select min(dtcol) from traqueur_times)), "
	s "vals_fin as (select * from traqueur_times where dtcol = (select max(dtcol) from traqueur_times))"
	s "select round(vals_fin.user_traqueur - vals_deb.user_traqueur) as \"${report_006_temps_CPU_user}\", "
	s "round(vals_fin.system_traqueur - vals_deb.system_traqueur) as \"${report_007_temps_CPU_systeme}\", "
	s "round(vals_fin.idle_traqueur - vals_deb.idle_traqueur) as \"${report_008_temps_CPU_idle}\", "
	s "CASE when upper(pg_temp.traqueur_system()) like '%LINUX%' THEN round(vals_fin.iowait_traqueur - vals_deb.iowait_traqueur) ELSE null END AS \"${report_009_temps_io}\""		
	s "from vals_deb, vals_fin;"
fi

if [[ ${mode_batch} -eq 0 ]] && [[ ${psutil} -eq 1 ]]; then
	#s "select round(max(total_traqueur)/1024/1024) as \"${report_034_total_memory}\" from traqueur_virtual_memory;"
	#s "select round(min(percent_traqueur)) as \"${report_035_min_memory_occupation}\" from traqueur_virtual_memory;"
	#s "select round(avg(percent_traqueur)) as \"${report_036_avg_memory_occupation}\" from traqueur_virtual_memory;"
	s "select round(max(percent_traqueur)) as \"${report_037_max_memory_occupation}\" from traqueur_virtual_memory;"

	#s "select round(max(total_traqueur)/1024/1024) as \"${report_038_total_swap}\" from traqueur_swap_memory;"
	#s "select round(min(percent_traqueur)) as \"${report_039_min_swap_occupation}\" from traqueur_swap_memory;"
	#s "select round(avg(percent_traqueur)) as \"${report_040_avg_swap_occupation}\" from traqueur_swap_memory;"
	s "select round(max(percent_traqueur)) as \"${report_041_max_swap_occupation}\" from traqueur_swap_memory;"
	
	s "with vals_sw_deb as (select * from traqueur_swap_memory where dtcol = (select min(dtcol) from traqueur_swap_memory)), "
	s "vals_sw_fin as (select * from traqueur_swap_memory where dtcol = (select max(dtcol) from traqueur_swap_memory)) "
	s "select pg_size_pretty((vals_sw_fin.sin_traqueur - vals_sw_deb.sin_traqueur + vals_sw_fin.sout_traqueur - vals_sw_deb.sout_traqueur)::bigint) as \"${report_042_swapped_memory}\" "
	s "from vals_sw_deb, vals_sw_fin;"
fi

if [[ ${mode_batch} -eq 0 ]] && [[ ${pg_latence} -eq 1 ]]; then
s "with haut as (select dtcol, context, read_time, reads, write_time, writes, writeback_time, writebacks, extends, extend_time, fsync_time, fsyncs, evictions, stats_reset from traqueur_io_stats where dtcol = (select max(dtcol) from traqueur_io_stats)), bas as (select dtcol, context, read_time, reads, write_time, writes, writeback_time, writebacks, extends, extend_time, fsync_time, fsyncs, evictions, stats_reset from traqueur_io_stats where dtcol = (select min(dtcol) from traqueur_io_stats)) select haut.context \"Contexte\", case when (sum(haut.reads)-sum(bas.reads)) <> 0 then round(((sum(haut.read_time)-sum(bas.read_time))/(sum(haut.reads)-sum(bas.reads)))::numeric,2) else null end \"${report_028_latence_lectures}\", case when (sum(haut.writes)-sum(bas.writes)) <> 0 then round(((sum(haut.write_time)-sum(bas.write_time))/(sum(haut.writes)-sum(bas.writes)))::numeric,2) else null end \"${report_029_latence_ecritures}\", case when (sum(haut.writebacks)-sum(bas.writebacks)) <> 0 then round(((sum(haut.writeback_time)-sum(bas.writeback_time))/(sum(haut.writebacks)-sum(bas.writebacks)))::numeric,2) else null end \"${report_030_latence_ecritures_permanentes}\", case when (sum(haut.extends)-sum(bas.extends)) <> 0 then round(((sum(haut.extend_time)-sum(bas.extend_time))/(sum(haut.extends)-sum(bas.extends)))::numeric,2) else null end \"${report_031_latence_extensions_fichiers}\", case when (sum(haut.fsyncs)-sum(bas.fsyncs)) <> 0 then round(((sum(haut.fsync_time)-sum(bas.fsync_time))/(sum(haut.fsyncs)-sum(bas.fsyncs)))::numeric,2) else null end \"${report_032_latence_fsyncs}\", sum(haut.evictions)-sum(bas.evictions) \"${report_033_evictions}\" from haut join bas on (haut.context = bas.context) where haut.stats_reset = bas.stats_reset group by haut.context order by haut.context asc;"
fi

s "\o /dev/null"



if [[ ${mode_batch} -eq 0 ]]; then  	
	information "${info_002_execution_traque}"  
else
	information "${info_010_execution_traque_batch}" 
fi
	
psql ${psql_connect_string} -f ${TRAQUEUR_W}/traqueur.${process_number}  -v ON_ERROR_STOP=1 --quiet -X
GLOBAL_RESULT="$?"
del_work_files ${process_number}

exit ${GLOBAL_RESULT}
