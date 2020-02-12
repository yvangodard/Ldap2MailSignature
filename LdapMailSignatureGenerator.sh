#! /bin/bash

version="LdapMailSignatureGenerator v 1.0 - 2019 - Yvan GODARD - godardyvan@gmail.com - http://goo.gl/xr73Mt"
scriptDir=$(dirname $0)
scriptName=$(basename $0)
scriptNameWithoutExt=$(echo "${scriptName}" | cut -f1 -d '.')
versionOsX=$(sw_vers -productVersion | awk -F '.' '{print $(NF-1)}')
ldapUrl=""
ldapDnBase=""
racine=""
modele=""
withLdapBind="no"
ldapAdminUid=""
ldapAdminPass=""
ldapDnUserBranch="cn=users"
filterOnDomain=""
domainEmail=""
userUid=$(basename ~)
ipFilter=0
help="no"
logActive=0
homeDir=$(echo ~)
log=${homeDir%/}/Library/logs/${scriptNameWithoutExt}.log
dirExport=${homeDir%/}/Desktop
clefIdentifiant=${scriptNameWithoutExt}
verbosity=0
modeMapping="none"
nombreAnciennesSignatures=0
# Fichier temp
logTemp=$(mktemp /tmp/${scriptNameWithoutExt}.XXXXX)
tempIp=$(mktemp /tmp/${scriptNameWithoutExt}_tempip.XXXXX)
listeIp=$(mktemp /tmp/${scriptNameWithoutExt}_listeIP.XXXXX)
contentUser=$(mktemp /tmp/${scriptNameWithoutExt}_fiche.XXXXX)
contentUserBase=$(mktemp /tmp/${scriptNameWithoutExt}_fiche_decode.XXXXX)
listeMail=$(mktemp /tmp/${scriptNameWithoutExt}_mail.XXXXX)
listeTel=$(mktemp /tmp/${scriptNameWithoutExt}_tel.XXXXX)
listeMobile=$(mktemp /tmp/${scriptNameWithoutExt}_mobile.XXXXX)
listeSkype=$(mktemp /tmp/${scriptNameWithoutExt}_skype.XXXXX)
listeAnciennesSignatures=$(mktemp /tmp/${scriptNameWithoutExt}_anciennes_signatures.XXXXX)
# variables dépendantes de l'OS
[[ ${versionOsX} -eq 8 ]] && mimeVersion="Mime-Version: 1.0 (Mac OS X Mail 6.0 \(1485\))"
[[ ${versionOsX} -eq 9 ]] && mimeVersion="Mime-Version: 1.0 (Mac OS X Mail 6.0 \(1485\))"
[[ ${versionOsX} -eq 10 ]] && mimeVersion="Mime-Version: 1.0 (Mac OS X Mail 8.2 \(2070.6\))"
[[ ${versionOsX} -eq 11 ]] && mimeVersion="Mime-Version: 1.0 (Mac OS X Mail 9.0 \(3054\))"
[[ ${versionOsX} -eq 12 ]] && mimeVersion="Mime-Version: 1.0 (Mac OS X Mail 9.0 \(3093\))"
[[ ${versionOsX} -eq 13 ]] && mimeVersion="Mime-version: 1.0 (Mac OS X Mail 11.5 \(3445.9.1\))"
[[ ${versionOsX} -eq 14 ]] && mimeVersion="Mime-version: 1.0 (Mac OS X Mail 12.0 \(3445.100.39\))"
[[ ${versionOsX} -eq 15 ]] && mimeVersion="Mime-Version: 1.0 (Mac OS X Mail 13.0 \(3608.60.0.2.5\))"
# Définition de l'emplacement des signatures et du format
[[ ${versionOsX} -eq 8 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V2/MailData/Signatures
[[ ${versionOsX} -eq 9 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V2/MailData/Signatures
[[ ${versionOsX} -eq 10 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V2/MailData/Signatures
[[ ${versionOsX} -eq 11 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V3/MailData/Signatures
[[ ${versionOsX} -eq 12 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V4/MailData/Signatures
[[ ${versionOsX} -eq 13 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V5/MailData/Signatures
[[ ${versionOsX} -eq 14 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V6/MailData/Signatures
[[ ${versionOsX} -eq 15 ]] && emplacementSignatures=${homeDir%/}/Library/Mail/V7/MailData/Signatures
# Définition de l'emplacement du plist général de Mail
[[ ${versionOsX} -eq 13 ]] && plistFileMail=${homeDir%/}/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail.plist
[[ ${versionOsX} -eq 14 ]] && plistFileMail=${homeDir%/}/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail.plist
[[ ${versionOsX} -eq 15 ]] && plistFileMail=${homeDir%/}/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail.plist

help () {
	echo -e "$version\n"
	echo -e "Cet outil permet de personnaliser un template de siganture Mail.app en utilisant des informations issues d'un serveur LDAP."
	echo -e "Cet outil est placé sous la licence Creative Commons 4.0 BY NC SA."
	echo -e "\nAvertissement:"
	echo -e "Cet outil est distribué dans support ou garantie, la responsabilité de l'auteur ne pourrait être engagée en cas de dommage causé à vos données."
	echo -e "\nUtilisation:"
	echo -e "./${scriptName} [-h] | -s <URL Serveur LDAP> -r <DN Racine>"
	echo -e "                                      -t <template signature>" 
	echo -e "                                      [-a <LDAP admin UID>] [-p <LDAP admin password>]"
	echo -e "                                      [-u <DN relatif branche Users>]"
	echo -e "                                      [-D <filtre domaine email>] [-d <domaine email prioritaire>]"
	echo -e "                                      [-U <UID de l'utilisateur à traiter>] [-e <mode mapping>]"
	echo -e "                                      [-i <IP depuis lesquelles lancer le processus>]"
	echo -e "                                      [-P <chemin export>] [-j <log file>] [-v <verbosité>]"
	echo -e "\n\t-h:                                   Affiche cette aide et quitte."
	echo -e "\nParamètres obligatoires :"
	echo -e "\t-r <DN Racine> :                      DN de base de l'ensemble des entrées du LDAP (ex. : 'dc=server,dc=office,dc=com')."
	echo -e "\t-s <URL Serveur LDAP> :               URL du serveur LDAP (ex. : 'ldap://ldap.serveur.office.com')."
	echo -e "\t-t <template signature> :             Chemin complet du fichier de siganture Mail.app source à utiliser,"
	echo -e "\t                                      avec extension .mailsignature (ex. : '/Users/moi/templates/master_template.mailsignature')."
	echo -e "\nParamètres optionnels :"
	echo -e "\t-a <LDAP admin UID> :                 UID de l'administrateur ou utilisateur LDAP si un Bind est nécessaire"
	echo -e "\t                                      pour consulter l'annuaire (ex. : 'diradmin')."
	echo -e "\t-p <LDAP admin password> :            Mot de passe de l'utilisateur si un Bind est nécessaire pour consulter"
	echo -e "\t                                      l'annuaire (sera demandé si absent)."
	echo -e "\t-u <DN relatif branche Users> :       DN relatif de la branche Users du LDAP"
	echo -e "\t                                      (ex. : 'cn=allusers', par défaut : '${ldapDnUserBranch}')"
	echo -e "\t-D <filtre domaine email> :           L'utilisation de ce paramètre permet de restreindre la processus aux utilisateurs"
	echo -e "\t                                      du LDAP disposant d'une adresse email contenant un domaine, sans le '@'"
	echo -e "\t                                      (ex. : '-D mondomaine.fr' ou '-D serveur.mail.domaine.fr')."
	echo -e "\t-d <domaine email prioritaire> :      Permet de n'exporter que les adresses email contenant le domaine, sans le '@'"
	echo -e "\t                                      (ex. : '-d mondomaine.fr' ou '-d serveur.mail.domaine.fr')."
	echo -e "\t-U <UID de l'utilisateur à traiter> : Utilisateur à rechercher dans le LDAP pour créer un template personnalisé,"
	echo -e "\t                                      par défaut l'UID suivant est utilisé : ${userUid}"
	echo -e "\t-e <mode mapping> :                   Mode de mapping de la signature créée avec les comptes emails [none|all|ALL|uid|UID]: "
	echo -e "\t                                      - e none : option sélectionnée par défaut, la siganture n'est affectée à aucun compte email,"
	echo -e "\t                                      - e all : ajout sur tous les comptes,"
	echo -e "\t                                      - e ALL : ajout sur tous les comptes, avec signature sélectionnée par défaut,"
	echo -e "\t                                      - e uid : ajout sur tous les comptes email correspondants à l'UID,"
	echo -e "\t                                      - e UID : ajout signature par défaut sur tous les comptes email correspondants à l'UID."
	echo -e "\t-i <IP> :                             Utiliser cette option pour restreindre le lancement de la commande"
	echo -e "\t                                      uniquement depuis certaines adresse IP, séparées par le caractère '%'"
	echo -e "\t                                      (ex. : '123.123.123.123%12.34.56.789')"
	echo -e "\t-P <chemin export> :                  Chemin complet du dossier vers lequel exporter le résultat"
	echo -e "\t                                      (ex. : '~/Desktop/' ou '/var/templatesmail/', par défaut : '${STANDARD_dirExport}'"
	echo -e "\t-j <fichier Log> :                    Assure la journalisation dans un fichier de log à renseigner en paramètre."
	echo -e "\t                                      (ex. : '${log}')"
	echo -e "\t                                      ou utilisez 'default' (${log})"
	echo -e "\t-v <verbosité> :                      Réglage du niveau de verbosité du script. Par défaut, 0."
	echo -e "\t                                      Pour obtenir davantage de retours dans votre console ou votre log,"
	echo -e "\t                                      utilisez '-v 1'."
}

function error () {
	# 1 Pas de connection internet
	# 2 Internet OK mais pas connecté au réseau local
	# 3 LDAP injoignable
	# 4 User inexistant
	# 5 Pas de correspondance pour ce domaine
	# 6 Fichier source modèle inexistant
	# 7 Autre erreur
	# 8 Conflit entre plusieurs anciennes signatures. Utilisez -v 1 pour augmenter la verbosité et voir quels sont ces fichiers.
	# 9 Dossier de destination impossible à créer
	echo -e "\n*** Erreur ${1} ***"
	echo -e ${2}
	alldone ${1}
}

function alldone () {
	# Journalisation si nécessaire et redirection de la sortie standard
	[ ${1} -eq 0 ] && echo "" && echo ">>> Processus terminé OK !"
	if [ ${logActive} -eq 1 ]; then
		exec 1>&6 6>&-
		[[ ! -f ${log} ]] && touch ${log}
		cat ${logTemp} >> ${log}
		cat ${logTemp}
	fi
	chflags uchg ${allSignaturesPlistFile}
	chflags uchg ${accountSignaturesMapPlist}
	chflags uchg ${plistFileMail}
	# Suppression des fichiers et répertoires temporaires
	rm -R /tmp/${scriptNameWithoutExt}*
	exit ${1}
}

# Fonction utilisée plus tard pour les résultats de requêtes LDAP encodées en base64
function base64decode () {
	echo ${1} | grep :: > /dev/null 2>&1
	if [ $? -eq 0 ] 
		then
		value=$(echo ${1} | grep :: | awk '{print $2}' | openssl enc -base64 -d )
		attribute=$(echo ${1} | grep :: | awk '{print $1}' | awk 'sub( ".$", "" )' )
		echo "${attribute} ${value}"
	else
		echo ${1}
	fi
}

# Encodage des accents en HTML
function htmlEncode () {
	cat ${1} | \
	sed 's/à/\&agrave;/' | \
	sed 's/À/\&Agrave;/' | \
	sed 's/á/\&aacute;/' | \
	sed 's/Á/\&Aacute;/' | \
	sed 's/â/\&acirc;/' | \
	sed 's/Â/\&Acirc;/' | \
	sed 's/ã/\&atilde;/' | \
	sed 's/Ã/\&Atilde;/' | \
	sed 's/ä/\&auml;/' | \
	sed 's/Ä/\&Auml;/' | \
	sed 's/å/\&aring;/' | \
	sed 's/Å/\&Aring;/' | \
	sed 's/æ/\&aelig;/' | \
	sed 's/Æ/\&AElig;/' | \
	sed 's/è/\&egrave;/' | \
	sed 's/È/\&Egrave;/' | \
	sed 's/é/\&eacute;/' | \
	sed 's/É/\&Eacute;/' | \
	sed 's/ê/\&ecirc;/' | \
	sed 's/Ê/\&Ecirc;/' | \
	sed 's/ë/\&euml;/' | \
	sed 's/Ë/\&Euml;/' | \
	sed 's/ì/\&igrave;/' | \
	sed 's/Ì/\&Igrave;/' | \
	sed 's/í/\&iacute;/' | \
	sed 's/Í/\&Iacute;/' | \
	sed 's/î/\&icirc;/' | \
	sed 's/Î/\&Icirc;/' | \
	sed 's/ï/\&iuml;/' | \
	sed 's/Ï/\&Iuml;/' | \
	sed 's/ò/\&ograve;/' | \
	sed 's/Ò/\&Ograve;/' | \
	sed 's/ó/\&oacute;/' | \
	sed 's/Ó/\&Oacute;/' | \
	sed 's/ô/\&ocirc;/' | \
	sed 's/Ô/\&Ocirc;/' | \
	sed 's/õ/\&otilde;/' | \
	sed 's/Õ/\&Otilde;/' | \
	sed 's/ö/\&ouml;/' | \
	sed 's/Ö/\&Ouml;/' | \
	sed 's/ø/\&oslash;/' | \
	sed 's/Ø/\&Oslash;/' | \
	sed 's/ù/\&ugrave;/' | \
	sed 's/Ù/\&Ugrave;/' | \
	sed 's/ú/\&uacute;/' | \
	sed 's/Ú/\&Uacute;/' | \
	sed 's/û/\&ucirc;/' | \
	sed 's/Û/\&Ucirc;/' | \
	sed 's/ü/\&uuml;/' | \
	sed 's/Ü/\&Uuml;/' | \
	sed 's/ñ/\&ntilde;/' | \
	sed 's/Ñ/\&Ntilde;/' | \
	sed 's/ç/\&ccedil;/' | \
	sed 's/Ç/\&Ccedil;/' | \
	sed 's/ý/\&yacute;/' | \
	sed 's/Ý/\&Yacute;/' | \
	sed 's/ß/\&szlig;/'
}

# Fonction de test pour vérifier si Mail.app est ouvert et le quitter automatiquement
function testMailOpenAndQuit {
	# On teste si Mail.app est ouvert et on quitte le cas échéant
	ps cax | grep Mail$ > /dev/null 2>&1 ; codeRetour=$(echo $?)
	if [[ ${codeRetour} -eq "0" ]]; then
		[[ ${verbosity} -eq "1" ]] && echo -e "\nMail.app est ouvert, nous quittons avant de poursuivre."
		while [[ ${codeRetour} -eq "0" ]]
		do
			pidMail=$(ps cax | grep Mail$ | grep -o '^[ ]*[0-9]*' | tr -d '\r\n' | sed "s/ //g")
		    kill ${pidMail}
		    sleep 1
		    ps cax | grep Mail$ > /dev/null 2>&1 ; codeRetour=$(echo $?)
		done
	fi
}

# Vérification des options/paramètres du script 
optsCount=0
while getopts "hr:s:t:a:p:u:D:d:e:i:P:j:U:v:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		r)	ldapDnBase=${OPTARG}
			let optsCount=$optsCount+1
						;;
	    s) 	ldapUrl=${OPTARG}
			let optsCount=$optsCount+1
						;;
	    t) 	modele=${OPTARG}
			let optsCount=$optsCount+1
						;;
		a)	ldapAdminUid=${OPTARG}
			[[ ${ldapAdminUid} != "" ]] && withLdapBind="yes"
						;;
		p)	ldapAdminPass=${OPTARG}
                        ;;
		u) 	ldapDnUserBranch=${OPTARG}
						;;
		D)	filterOnDomain=${OPTARG}
                        ;;
		d)	domainEmail=${OPTARG}
                        ;;
        U)	if [[ ! -z ${OPTARG} ]]; then
				userUid=${OPTARG}
			else
				userUid=$(basename ~)
			fi
						;;
		e)	modeMapping=${OPTARG}
						;;				
		i)	[[ ! -z ${OPTARG} ]] && echo ${OPTARG} | perl -p -e 's/%/\n/g' | perl -p -e 's/ //g' | awk '!x[$0]++' >> ${listeIp}
			ipFilter=1
                        ;;
        P) 	[[ ! -z ${OPTARG} ]] && dirExport=${OPTARG%/}
						;;
        j)	[ $OPTARG != "default" ] && log=${OPTARG}
			logActive=1
                        ;;
        v) 	verbosity=${OPTARG}
                        ;;
	esac
done

if [[ ${optsCount} != "3" ]]
	then
        help
        error 7 "Les paramètres obligatoires n'ont pas été renseignés."
fi

if [[ ${help} = "yes" ]]
	then
	help
fi

if [[ ${withLdapBind} = "yes" ]] && [[ ${ldapAdminPass} = "" ]]
	then
	echo "Entrez le mot de passe LDAP pour uid=${ldapAdminUid},${ldapDnUserBranch},${ldapDnBase} :" 
	read -s ldapAdminPass
fi

# Redirection de la sortie strandard vers le fichier de log
if [ ${logActive} -eq 1 ]; then
	echo -e "\n >>> Please wait ... >>> Merci de patienter ..."
	exec 6>&1
	exec >> ${logTemp}
fi

echo -e "\n****************************** `date` ******************************\n"
echo -e "$0 démarré..."

# Par sécurité, attendons quelques instants
sleep 3

# Testons si le paramètre de verbosité est correct
if [[ ${verbosity} -ne 0 ]] && [[ ${verbosity} -ne 1 ]]; then
	echo -e "\nVous avez sélectionnée l'option \"-v ${verbosity}\" hors \"-v ${verbosity}\" n'est pas un paramètre autorisé."
	echo -e "L'option -v n'accepte que les valeurs \"-v 0\" ou \"-v 1\"."
	echo -e "Pour ne pas interrompre l'usage du script, nous continuons avec le niveau de verbosité maximum, soit \"-v 1\"."
fi

# Testons si une connection internet est ouverte
dig +short myip.opendns.com @resolver1.opendns.com > /dev/null 2>&1
[ $? -ne 0 ] && error 1 "Non connecté à internet."

curl -s ifconfig.me > ${tempIp}
echo -e "\nAdresse IP actuelle : $(cat ${tempIp})"

# Testons si nous sommes connectés sur un réseau ayant pour IP Publique une IP autorisée
if [[ ${ipFilter} -ne 0 ]]; then
	ipOk=O
	for IP in $(cat ${listeIp})
	do
		TEST_GREP=$(grep -c "$IP" ${tempIp})
		[ $TEST_GREP -eq 1 ] && let ipOk=$ipOk+1 && echo "Connecté au réseau autorisé sur l'IP publique "$(cat ${tempIp})"."
	done
	[[ ${ipOk} -eq 0 ]] && error 2 "Connecté à internet hors du réseau local."
fi

# Test connection LDAP
echo -e "\nConnecting LDAP at $ldapUrl..."
[[ ${withLdapBind} = "no" ]] && ldapCommandBegin="ldapsearch -LLL -H ${ldapUrl} -x"
[[ ${withLdapBind} = "yes" ]] && ldapCommandBegin="ldapsearch -LLL -H ${ldapUrl} -D uid=${ldapAdminUid},${ldapDnUserBranch},${ldapDnBase} -w ${ldapAdminPass}"

${ldapCommandBegin} -b ${ldapDnUserBranch},${ldapDnBase} > /dev/null 2>&1
[ $? -ne 0 ] && error 3 "Problème de connexion au serveur LDAP ${ldapUrl}.\nVérifiez vos paramètres de connexion."

# Test si l'utilisateur existe dans le ldap
[[ -z $(${ldapCommandBegin} -b ${ldapDnUserBranch},${ldapDnBase} -x uid=${userUid}) ]] && error 4 "Aucune correspondance avec l'identifiant ${userUid} trouvé dans le LDAP ${ldapUrl}, dans la branche '${ldapDnUserBranch},${ldapDnBase}'."
[[ ! ${filterOnDomain} == "" ]] && [[ -z $(${ldapCommandBegin} -b ${ldapDnUserBranch},${ldapDnBase} -x uid=${userUid} mail | grep ${filterOnDomain}) ]] && error 5 "Aucune correspondance pour ${filterOnDomain} avec l'identifiant ${userUid} trouvé dans le LDAP ${ldapUrl}, dans la branche '${ldapDnUserBranch},${ldapDnBase}'."

# Test si le modèle de signature existe
[[ ! -f ${modele} ]] && error 6 "Le template de signature ${modele} n'existe pas ou n'est pas lisible."

# Test répertoire export
[[ ! -d ${dirExport} ]] && mkdir -p ${dirExport}
[[ ! -d ${dirExport} ]] && error 7 "Problème pour accéder au répertoire '${dirExport}'."
[[ ! -w ${dirExport} ]] && error 7 "Problème de droits d'accès en écriture au dossier ${dirExport}'."

# Test option ModeMapping
if [[ ! ${modeMapping} == "none" ]] && [[ ! ${modeMapping} == "all" ]] && [[ ! ${modeMapping} == "ALL" ]] && [[ ! ${modeMapping} == "uid" ]] && [[ ! ${modeMapping} == "UID" ]] ; then
	echo -e "\nVous avez sélectionnée l'option \"-e ${modeMapping}\" hors \"${modeMapping}\" n'est pas un paramètre autorisé."
	echo -e "Seuls les paramètres \"ALL\", \"all\", \"UID\", \"uid\", \"none\" sont autorisés."
	echo -e "Pour ne pas bloquer l'exécution du script nous basculons sur l'option \"-e none\"."
fi

################################################################################
# ETAPE 1 : Export variables depuis LDAP
################################################################################

# Récupérer les variables nécessaires
${ldapCommandBegin} -b ${ldapDnUserBranch},${ldapDnBase} -x uid=${userUid} givenName sn cn title telephoneNumber mobile mail apple-company street postalCode l c apple-imhandle resEnJobtTitle > ${contentUserBase}

# Correction to support LDIF splitted lines, thanks to Guillaume Bougard (gbougard@pkg.fr)
perl -n -e 'chomp ; print "\n" unless (substr($_,0,1) eq " " || !defined($lines)); $_ =~ s/^\s+// ; print $_ ; $lines++;' -i "${contentUserBase}"

# Décodage des informations
OLDIFS=$IFS; IFS=$'\n'
for LINE in $(cat ${contentUserBase})
do
	base64decode $LINE >> ${contentUser}
done
IFS=$OLDIFS

# Récupération des données depuis le LDAP
NOMCOMPLET=$(cat ${contentUser} | grep ^cn: | perl -p -e 's/cn: //g')
NOM=$(cat ${contentUser} | grep ^sn: | perl -p -e 's/sn: //g')
PRENOM=$(cat ${contentUser} | grep ^givenName: | perl -p -e 's/givenName: //g')
TITRE=$(cat ${contentUser} | grep ^title: | perl -p -e 's/title: //g')
ENGLISHTITLE=$(cat ${contentUser} | grep ^resEnJobtTitle: | perl -p -e 's/resEnJobtTitle: //g')
[[ -z ${NOMCOMPLET} ]] && NOMCOMPLET=$(echo "${PRENOM} ${NOM}")

# Email
# Si plusieurs emails sont renseignés pour l'utilisateur dans le LDAP on garde prioritairement 
# celui qui contient l'UID de l'utilisateur 
# et si le paramètre -d est utilisé on garde prioritairement (si l'un des emails correspond)
# une adresse email qui contient le nom de domaine renseigné en paramètre
cat ${contentUser} | grep ^mail: | perl -p -e 's/mail: //g' > ${listeMail}
linesNumber=$(cat ${listeMail} | grep "." | wc -l)
if [ ${linesNumber} -eq 1 ]; then
	EMAIL=$(head -n 1 ${listeMail})
elif [ ${linesNumber} -gt 1 ]; then
	if [ -z ${domainEmail} ]; then
		cat ${listeMail} | grep ${userUid} > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			EMAIL=$(head -n 1 ${listeMail})
		else
			EMAIL=$(cat ${listeMail} | grep ${userUid} | head -n 1)
		fi
	else
		cat ${listeMail} | grep ${domainEmail} | grep ${userUid} > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			EMAIL=$(cat ${listeMail} | grep ${domainEmail} | grep ${userUid} | head -n 1)
		else
			cat ${listeMail} | grep ${domainEmail} > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				EMAIL=$(cat ${listeMail} | grep ${domainEmail} | head -n 1)
			else
				cat ${listeMail} | grep ${userUid} > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					EMAIL=$(cat ${listeMail} | grep ${userUid} | head -n 1)
				else
					EMAIL=$(head -n 1 ${listeMail})
				fi
			fi
		fi
	fi
fi
linesNumber=""

# Skype
# Si plusieurs login Skype sont renseignés pour l'utilisateur dans le LDAP on garde prioritairement 
# celui qui contient l'UID de l'utilisateur 
# et si le paramètre -d est utilisé on garde prioritairement (si l'un des pseudos Skype correspond)
# un pseudo Skype qui contient le nom de domaine renseigné en paramètre
OLDIFS=$IFS; IFS=$'\n'
cat ${contentUser} | grep ^'apple-imhandle: Skype:' | perl -p -e 's/apple-imhandle: Skype://g' > ${listeSkype}
IFS=$OLDIFS
linesNumber=$(cat ${listeSkype} | wc -l)
if [ ${linesNumber} -eq 1 ]; then
	SKYPE=$(head -n 1 ${listeSkype})
elif [ ${linesNumber} -gt 1 ]; then
	if [ -z ${domainEmail} ]; then
		cat ${listeSkype} | grep ${userUid} > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			SKYPE=$(head -n 1 ${listeSkype})
		else
			SKYPE=$(cat ${listeSkype} | grep ${userUid} | head -n 1)
		fi
	else
		cat ${listeSkype} | grep ${domainEmail} | grep ${userUid} > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			SKYPE=$(cat ${listeSkype} | grep ${domainEmail} | grep ${userUid} | head -n 1)
		else
			cat ${listeSkype} | grep ${domainEmail} > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				SKYPE=$(cat ${listeSkype} | grep ${domainEmail} | head -n 1)
			else
				cat ${listeSkype} | grep ${userUid} > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					SKYPE=$(cat ${listeSkype} | grep ${userUid} | head -n 1)
				else
					SKYPE=$(head -n 1 ${listeSkype})
				fi
			fi
		fi
	fi
fi

# Fonction formatant au format international les numéros de téléphone
function telFormat () {
	NUMBER_TEL=$(echo ${1} | perl -p -e 's/\.//g' | perl -p -e 's/ //g' | perl -p -e 's/\(//g' | perl -p -e 's/\)//g')
	if [[ ${#NUMBER_TEL} -eq 10 ]] && [[ ${NUMBER_TEL:0:1} -eq 0 ]]; then
		echo ${NUMBER_TEL:0:2}" "${NUMBER_TEL:2:2}" "${NUMBER_TEL:4:2}" "${NUMBER_TEL:6:2}" "${NUMBER_TEL:8:2}
	elif [[ ${#NUMBER_TEL} -eq 12 ]] && [[ ${NUMBER_TEL:0:1} == "+" ]]; then
		echo ${NUMBER_TEL:0:3}" (0)"${NUMBER_TEL:3:1}" "${NUMBER_TEL:4:2}" "${NUMBER_TEL:6:2}" "${NUMBER_TEL:8:2}" "${NUMBER_TEL:10:2}
	elif [[ ${#NUMBER_TEL} -eq 13 ]] && [[ ${NUMBER_TEL:0:1} == "+" ]]; then
		echo ${NUMBER_TEL:0:3}" (0)"${NUMBER_TEL:4:1}" "${NUMBER_TEL:5:2}" "${NUMBER_TEL:7:2}" "${NUMBER_TEL:9:2}" "${NUMBER_TEL:11:2}
	else
		echo ${NUMBER_TEL}
	fi
}

# Traitement numéro de téléphone direct
OLDIFS=$IFS; IFS=$'\n'
for LINE in $(cat ${contentUser} | grep ^telephoneNumber: | perl -p -e 's/telephoneNumber: //g'| perl -p -e 's/ //g')
do
	 telFormat ${LINE} >> ${listeTel}
done
LIGNEDIRECTE=$(cat ${listeTel} | perl -p -e 's/\n/ - /g' | awk 'sub( "...$", "" )')
IFS=$OLDIFS

# Traitement numéro de téléphone portable pro
OLDIFS=$IFS; IFS=$'\n'
for LINE in $(cat ${contentUser} | grep ^mobile: | perl -p -e 's/mobile: //g'| perl -p -e 's/ //g')
do
	 telFormat ${LINE} >> ${listeMobile}
done
MOBILE=$(cat ${listeMobile} | perl -p -e 's/\n/ - /g' | awk 'sub( "...$", "" )')
IFS=$OLDIFS

################################################################################
# ETAPE 2 : Recherche des signatures équivalentes antérieures
################################################################################

# On crée le dossier de destination s'il n'existe pas
if [[ ! -d ${emplacementSignatures%/} ]]; then
	mkdir -p ${emplacementSignatures%/}
	if [ $? -ne 0 ]; then
		error 9 "Problème rencontré lors de la création du dossier ${emplacementSignatures%/}"
	fi
fi

# On teste s'il y a des signatures dans le dossier
ls ${emplacementSignatures%/}/*.mailsignature > /dev/null 2>&1
if [ $? -eq 0 ]; then
	[[ ${verbosity} -eq "1" ]] && echo -e "\nNous allons rechercher '${clefIdentifiant} ${EMAIL}' dans les signatures pour identifier si une siganture a déjà été générée par ${scriptName}."
	for SIGNATURE in $(find ${emplacementSignatures%/} -name "*.mailsignature" -depth 1 -print)
	do
		[[ ${verbosity} -eq "1" ]] && echo "${SIGNATURE}"
		generatedByThisScript=0
		grep "${clefIdentifiant} ${EMAIL}" ${SIGNATURE} > /dev/null 2>&1
		[[ $? -eq 0 ]] && echo "${SIGNATURE}" >> ${listeAnciennesSignatures} && let nombreAnciennesSignatures=${nombreAnciennesSignatures}+1
	done

	[[ ${verbosity} -eq "1" ]] && [[ ${nombreAnciennesSignatures} -gt "0" ]] && echo -e "\nListe ancienne(s) signature(s) :" && cat ${listeAnciennesSignatures}
	[[ ${verbosity} -eq "1" ]] && [[ ${nombreAnciennesSignatures} -eq "0" ]] && echo -e "\nPas d'ancienne signature générée par notre script n'a été trouvée." 
else
	[[ ${verbosity} -eq "1" ]] && echo -e "\nPas de signature trouvée dans le dossier ${emplacementSignatures%/}." 
fi

# Définition du nom de fichier, si aucune ancienne signature générée par notre script n'est trouvée.
if [[ ${nombreAnciennesSignatures} -eq "0" ]]; then
	# On évite d'écraser un autre fichier
	nomOk=0
	until [[ ${nomOk} -eq "1" ]]
	do
		UUID=$(uuidgen)
		nouveauNom="${UUID}.mailsignature"
		[[ ! -e ${emplacementSignatures%/}/${nouveauNom} ]] && nomOk=1
	done
elif [[ ${nombreAnciennesSignatures} -eq "1" ]]; then
	nouveauNom="$(echo $(basename $(cat ${listeAnciennesSignatures})))"
	UUID=$(basename ${nouveauNom} | sed "s/\.mailsignature//g")
elif [[ ${nombreAnciennesSignatures} -gt "1" ]]; then
	error 8 "Conflit entre plusieurs anciennes signatures. Utilisez si besoin -v 1 pour augmenter la verbosité et voir quels sont ces fichiers."
fi
[[ ${verbosity} -eq "1" ]] && echo -e "\nNom de fichier de la siganture générée :" && echo "${nouveauNom}"

################################################################################
# ETAPE 3 : Modification du template avec les valeurs personnalisées
################################################################################

modeleUser=${dirExport%/}/${nouveauNom}
cd ${dirExport%/}

if [[ ${versionOsX} -gt 14 ]]; then
	echo "Content-Transfer-Encoding: 7bit" > ${modeleUser}
else
	echo "Content-Transfer-Encoding: quoted-printable" > ${modeleUser}
fi
echo "Content-Type: text/html;" >> ${modeleUser}
echo "charset=utf-8" >> ${modeleUser}
echo "Message-Id: <${UUID}>" >> ${modeleUser}
echo "${mimeVersion}" >> ${modeleUser}
echo "" >> ${modeleUser}
echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">" >> ${modeleUser}
[[ ${versionOsX} -gt 10 ]] && echo "<body>" >> ${modeleUser}

cat ${modele} >> ${modeleUser}

# Ajout de la clé d'identification de la signature générée par notre outil (commentaire HTML)
echo -e "\n<!-- ${clefIdentifiant} ${EMAIL} -->" >> ${modeleUser}

[[ ${versionOsX} -gt 10 ]] && echo "</body>" >> ${modeleUser}

## PERSONNALISATION

cat ${modeleUser} | perl -p -e "s/NOMCOMPLET/${NOMCOMPLET}/g" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old

if [[ -z ${TITRE} ]] ; then
	cat ${modeleUser} | grep -v TITRE > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
else
	cat ${modeleUser} | perl -p -e "s/TITRE/${TITRE}/g" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
fi

if [[ -z ${ENGLISHTITLE} ]] ; then
	cat ${modeleUser} | grep -v ENGLISHTITLE > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
else
	cat ${modeleUser} | perl -p -e "s/ENGLISHTITLE/${ENGLISHTITLE}/g" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
fi

if [[ -z ${LIGNEDIRECTE} ]] ; then
	cat ${modeleUser} | grep -v LIGNEDIRECTE > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
else
	cat ${modeleUser} | perl -p -e "s/LIGNEDIRECTE/${LIGNEDIRECTE}/g" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
fi

if [[ -z ${MOBILE} ]] ; then
	cat ${modeleUser} | grep -v MOBILE > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
else
	cat ${modeleUser} | perl -p -e "s/MOBILE/${MOBILE}/g" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
fi

if [[ -z ${EMAIL} ]] ; then
	cat ${modeleUser} | grep -v EMAIL > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
else
	cat ${modeleUser} | sed "s/EMAIL/${EMAIL}/" | sed "s/EMAIL/${EMAIL}/" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
fi

if [[ -z ${SKYPE} ]] ; then
	cat ${modeleUser} | grep -v SKYPE > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
else
	cat ${modeleUser} | perl -p -e "s/SKYPE/${SKYPE}/g" > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old
fi

# Lecture du résultat
[[ ${verbosity} -eq "1" ]] && echo -e "\nContenu de la signature générée :" && cat ${modeleUser}

# Encodage HTML des accents
htmlEncode ${modeleUser} > ${modeleUser}.new && mv ${modeleUser} ${modeleUser}.old && mv ${modeleUser}.new ${modeleUser} && rm ${modeleUser}.old

################################################################################
# ETAPE 4 : Générons le fichier de signature
################################################################################

# On teste si Mail.app est ouvert et on quitte le cas échéant
ps cax | grep Mail$ > /dev/null 2>&1 ; codeRetour=$(echo $?)
if [[ ${codeRetour} -eq "0" ]]; then
	[[ ${verbosity} -eq "1" ]] && echo -e "\nMail.app est ouvert, nous quittons avant de poursuivre."
	while [[ ${codeRetour} -eq "0" ]]
	do
		pidMail=$(ps cax | grep Mail$ | grep -o '^[ ]*[0-9]*' | tr -d '\r\n' | sed "s/ //g")
	    kill ${pidMail}
	    sleep 1
	    ps cax | grep Mail$ > /dev/null 2>&1 ; codeRetour=$(echo $?)
	done
fi

# On vérifie avec un hash MD5 si la signature générée est différente de celle déjà présente
if [[ ${nombreAnciennesSignatures} -eq "0" ]]; then
	if [[ -f ${emplacementSignatures%/}/${nouveauNom} ]]; then
		chflags -R nouchg ${emplacementSignatures%/}/${nouveauNom}
		rm -R ${emplacementSignatures%/}/${nouveauNom}
	fi 
	mv ${nouveauNom} ${emplacementSignatures%/}/
elif [[ ${nombreAnciennesSignatures} -eq "1" ]]; then
	# On teste le hash MD5 de l'ancienne signature
	oldMD5=$(md5 ${emplacementSignatures%/}/${nouveauNom} | sed "s/ //g" | awk -F '=' '{print $(NF)}')
	newMD5=$(md5 ${nouveauNom} | sed "s/ //g" | awk -F '=' '{print $(NF)}')
	echo ${oldMD5} | grep ${newMD5} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		[[ ${verbosity} -eq "1" ]] && echo -e "\nLe hash MD5 de la nouvelle signature HTML générée est différent de celle déjà présente, nous allons donc la remplacer."
		if [[ -f ${emplacementSignatures%/}/${nouveauNom} ]]; then
			chflags -R nouchg ${emplacementSignatures%/}/${nouveauNom}
			rm -R ${emplacementSignatures%/}/${nouveauNom}
		fi 
		mv ${nouveauNom} ${emplacementSignatures%/}/
	else 
		[[ ${verbosity} -eq "1" ]] && echo -e "\nLe hash MD5 de la nouvelle signature HTML générée est identique à celui de celle déjà présente, nous ne faisons aucune modification."
		rm ${nouveauNom}
	fi
elif [[ ${nombreAnciennesSignatures} -gt "1" ]]; then
	error 8 "Conflit entre plusieurs anciennes signatures. Utilisez si besoin -v 1 pour augmenter la verbosité et voir quels sont ces fichiers."
fi

chflags uchg ${emplacementSignatures%/}/${nouveauNom}


cd ${homeDir%/}

################################################################################
# ETAPE 5 : On enregistre la signature dans le fichier de préférences AllSignatures.plist 
################################################################################

allSignaturesPlistFile=${emplacementSignatures%/}/AllSignatures.plist
allSignaturesPlistFileNew=${dirExport%/}/AllSignatures.plist

# Pour travailler sur les fichiers plist, on les converti en XML si besoin
# On vérouille le fichier pour les utilisations futures
[[ -f ${allSignaturesPlistFile} ]] && chflags nouchg ${allSignaturesPlistFile}
[[ -f ${allSignaturesPlistFile} ]] && plutil -convert xml1 ${allSignaturesPlistFile}
[[ -f ${allSignaturesPlistFile} ]] && chflags nouchg ${allSignaturesPlistFile}

# On teste si le fichier AllSignatures.plist n'existe pas et on le créee
if [[ ! -e ${allSignaturesPlistFile} ]]; then
	touch ${allSignaturesPlistFile}
	echo '<?xml version="1.0" encoding="UTF-8"?>' > ${allSignaturesPlistFile}
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ${allSignaturesPlistFile}
	echo '<plist version="1.0">' >> ${allSignaturesPlistFile}
	echo '<array>' >> ${allSignaturesPlistFile}
	echo '</array>' >> ${allSignaturesPlistFile}
	echo '</plist>' >> ${allSignaturesPlistFile}
fi

xmllint --xpath '/plist/array/dict/string' ${allSignaturesPlistFile} | perl -p -e 's/<string>//g' | perl -p -e 's/<\/string>/\n/g' | grep '^[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*$' | grep "${UUID}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
	[[ ${verbosity} -eq "1" ]] && echo -e "\nLa signature est déjà enregistrée dans le fichier ${emplacementSignatures%/}/AllSignatures.plist."
else
	[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute la signature dans le fichier de préférences ${emplacementSignatures%/}/AllSignatures.plist."
	numLigneMailSignature=$(sed -n '/<array>/=' ${allSignaturesPlistFile})
	numLignesTotales=$(awk 'END {print NR}' ${allSignaturesPlistFile})
	head -n ${numLigneMailSignature} ${allSignaturesPlistFile} > ${allSignaturesPlistFileNew}
	echo "<dict>" >> ${allSignaturesPlistFileNew}
	echo "<key>SignatureIsRich</key>" >> ${allSignaturesPlistFileNew}
	echo "<true/>" >> ${allSignaturesPlistFileNew}
	echo "<key>SignatureName</key>" >> ${allSignaturesPlistFileNew}
	echo "<string>${NOMCOMPLET} - AutoGen</string>" >> ${allSignaturesPlistFileNew}
	echo "<key>SignatureUniqueId</key>" >> ${allSignaturesPlistFileNew}
	echo "<string>${UUID}</string>" >> ${allSignaturesPlistFileNew}
	echo "</dict>" >> ${allSignaturesPlistFileNew}
	tail -n $(($numLignesTotales-$numLigneMailSignature)) ${allSignaturesPlistFile} >> ${allSignaturesPlistFileNew}
	xmllint --format ${allSignaturesPlistFileNew} > ${allSignaturesPlistFileNew}.new && mv ${allSignaturesPlistFileNew} ${allSignaturesPlistFileNew}.old && mv ${allSignaturesPlistFileNew}.new ${allSignaturesPlistFileNew} && rm ${allSignaturesPlistFileNew}.old

	# On utilise la fonction testMailOpenAndQuit pour quitter automatiquement Mail.app si l'application est ouverte
	testMailOpenAndQuit

	rm ${allSignaturesPlistFile} && mv ${allSignaturesPlistFileNew} ${allSignaturesPlistFile}

	# On vérouille le fichier pour les utilisations futures
	chflags uchg ${allSignaturesPlistFile}
fi

################################################################################
# ETAPE 6 : On fait le mapping dans le fichier de préférences AccountsMap.plist
################################################################################

# On quitte si l'option "-e none" est sélectionnée ou si l'option "-e" n'est pas activée
[[ ${modeMapping} == "none" ]] && alldone 0

accountSignaturesMapPlist=${emplacementSignatures%/}/AccountsMap.plist

# On utilise la fonction testMailOpenAndQuit pour quitter automatiquement Mail.app si l'application est ouverte
testMailOpenAndQuit

# Par sécurité on attend quelques secondes
sleep 3

# On dévérouille les fichiers XML pour travailler dessus
[[ -f ${plistFileMail} ]] && chflags nouchg ${plistFileMail}
[[ -f ${accountSignaturesMapPlist} ]] && chflags nouchg ${accountSignaturesMapPlist}

# Pour travailler sur les fichiers plist on les converti en XML si besoin
[[ -f ${plistFileMail} ]] && plutil -convert xml1 ${plistFileMail}
##[[ -f ${accountSignaturesMapPlist} ]] && plutil -convert xml1 {accountSignaturesMapPlist}

# On crée le fichier de mapping s'il n'existe pas
if [[ ! -f ${accountSignaturesMapPlist} ]] || [[ -z $(cat ${accountSignaturesMapPlist}) ]]; then
	if [[ -z $(cat ${plistFileMail}) ]] ; then
		error 7 "Le fichier de configuration des signatures ${accountSignaturesMapPlist} n'existait pas et il a été impossible de le créer, car le fichier de configuration des comptes email ${plistFileMail} semble vide ou inexistant."
	fi
	# On détecte les UUID des comptes email paramétrés dans le fichier ${plistFileMail}
	emailAccountsUuids=$(/usr/libexec/PlistBuddy ${plistFileMail} -c "print :MailSections" | sed "s/ //g" | grep '[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*' | grep 'pop\|imap' )
	[[ -z ${emailAccountsUuids} ]] && error 7 "Le fichier de configuration des signatures ${accountSignaturesMapPlist} n'existait pas et il a été impossible de le créer, car aucun compte email n'a été détecté dans ${plistFileMail}."
	# On créé le début du fichier plist
	touch ${accountSignaturesMapPlist}
	echo '<?xml version="1.0" encoding="UTF-8"?>' > ${accountSignaturesMapPlist}
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ${accountSignaturesMapPlist}
	echo '<plist version="1.0">' >> ${accountSignaturesMapPlist}
	echo '<dict>' >> ${accountSignaturesMapPlist}
	for emailUUID in ${emailAccountsUuids}
	do
		onlyUUIDemail=$(echo ${emailUUID} | sed 's/\///g' | awk -F ':' '{print $(NF)}')
		echo "<key>${onlyUUIDemail}</key>" >> ${accountSignaturesMapPlist}
		echo '<dict>' >> ${accountSignaturesMapPlist}
		echo '<key>AccountURL</key>' >> ${accountSignaturesMapPlist}
		echo "<string>${emailUUID}</string>" >> ${accountSignaturesMapPlist}
		echo '<key>Signatures</key>' >> ${accountSignaturesMapPlist}
		echo '<array>' >> ${accountSignaturesMapPlist}
		echo '</array>' >> ${accountSignaturesMapPlist}
		echo '</dict>' >> ${accountSignaturesMapPlist}
	done
	echo '</dict>' >> ${accountSignaturesMapPlist}
	echo '</plist>' >> ${accountSignaturesMapPlist}
	xmllint --format ${accountSignaturesMapPlist} > ${accountSignaturesMapPlist}.new && mv ${accountSignaturesMapPlist} ${accountSignaturesMapPlist}.old && mv ${accountSignaturesMapPlist}.new ${accountSignaturesMapPlist} && rm ${accountSignaturesMapPlist}.old
fi

# On liste les comptes emails qui pré-existent dans le fichier de mapping
listeEmailAccountsPlist=$(xmllint --xpath '/plist/dict/key' ${accountSignaturesMapPlist} | perl -p -e 's/<key>//g' | perl -p -e 's/<\/key>/\n/g' | grep '^[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*$')	

# Si aucun compte email 
[[ -z ${listeEmailAccountsPlist} ]] && error 7 "Aucun compte email paramétré dans ${accountSignaturesMapPlist}." 

# On traite les cas ALL et all / uid et UID dans le fichier de mapping
for emailAccountUuid in ${listeEmailAccountsPlist}
do
	numberOfAlreadyRegisteredSignatures=0
	numberOfSignatureToAdd=0
	emailAccountDescription=$(/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "print :${emailAccountUuid}:AccountURL" | sed "s/ //g" )
	# Test si la signature est déjà enregistréee
	/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "print :${emailAccountUuid}" | sed "s/ //g" | grep '^[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*$' | grep ${UUID} > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		[[ ${verbosity} -eq "1" ]] && echo -e "\nLa signature est déjà enregistrée dans ${accountSignaturesMapPlist} pour la boite mail ${emailAccountDescription}."
	else
		[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute la référence à la signature ${UUID} pour la boite mail ${emailAccountDescription} dans le fichier de préférences ${accountSignaturesMapPlist}."

		# On teste si l'entrée signature existe
		/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "print :${emailAccountUuid}:Signatures" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute avec PlistBuddy l'entrée :${emailAccountUuid}:Signatures dans ${accountSignaturesMapPlist}"
			/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "add :${emailAccountUuid}:Signatures array"
		else
			echo "OK"
		fi

		# Nombre de signatures déjà enregistrées
		numberOfAlreadyRegisteredSignatures=$(/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "print :${emailAccountUuid}:Signatures" | sed "s/ //g" | grep '^[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*$' | awk 'END {print NR}')
		numberOfSignatureToAdd=$(( ${numberOfAlreadyRegisteredSignatures}+1 ))

		if [[ ${modeMapping} == "uid" ]] || [[ ${modeMapping} == "UID" ]] ; then
			# On teste si la description contient d'UID de l'utilisateur
			echo ${emailAccountDescription} | grep ${userUid} > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				[[ ${verbosity} -eq "1" ]] && echo -e "\nVous avez sélectionné l'option \"-e ${modeMapping}\" et le compte email ${emailAccountDescription} semble contenir votre UID.\nNous ajoutons le lien de votre signature."
				/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "add :${emailAccountUuid}:Signatures array"
			fi
		fi
		if [[ ${modeMapping} == "all" ]] || [[ ${modeMapping} == "ALL" ]] ; then
			/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "add :${emailAccountUuid}:Signatures:${numberOfSignatureToAdd} string ${UUID}"
		fi
	fi
done

# On travaille désormais sur le PLIST plistFileMail
# On teste si <key>SignatureSelectionMethods</key> existe
/usr/libexec/PlistBuddy ${plistFileMail} -c "print :SignatureSelectionMethods" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute avec PlistBuddy l'entrée :SignatureSelectionMethods dans ${plistFileMail}."
	/usr/libexec/PlistBuddy ${plistFileMail} -c "add :SignatureSelectionMethods dict"
fi	

emailAccountsUuids=$(/usr/libexec/PlistBuddy ${plistFileMail} -c "print :MailSections" | sed "s/ //g" | grep '[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*' | grep 'pop\|imap' )

# On ajoute l'information dans plistFileMail > SignatureSelectionMethods
if [[ ${modeMapping} == "all" ]] || [[ ${modeMapping} == "ALL" ]] ; then
	# Pour chaque compte email de plistFileMail
	for emailAccountUuid in $(echo ${emailAccountsUuids} | sed 's/\///g' | awk -F ':' '{print $(NF)}')
	do
		/usr/libexec/PlistBuddy ${plistFileMail} -c "print :SignatureSelectionMethods:${emailAccountUuid}" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute avec PlistBuddy l'entrée :SignatureSelectionMethods:${emailAccountUuid} SelectedOnly dans ${plistFileMail}."
			/usr/libexec/PlistBuddy ${plistFileMail} -c "add :SignatureSelectionMethods:${emailAccountUuid} string"
			/usr/libexec/PlistBuddy ${plistFileMail} -c "set :SignatureSelectionMethods:${emailAccountUuid} SelectedOnly"
		else
			[[ ${verbosity} -eq "1" ]] && echo -e "\nVotre fichier ${plistFileMail} contient déjà l'entrée :SignatureSelectionMethods:${emailAccountUuid} SelectedOnly."
		fi
	done
fi
if [[ ${modeMapping} == "uid" ]] || [[ ${modeMapping} == "UID" ]] ; then
	for emailAccountUuid in ${listeEmailAccountsPlist}
	do
		emailAccountDescription=$(/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "print :${emailAccountUuid}:AccountURL" | sed "s/ //g" )
		echo ${emailAccountDescription} | grep ${userUid} > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			[[ ${verbosity} -eq "1" ]] && echo -e "\nVous avez sélectionné l'option \"-e ${modeMapping}\" et le compte email ${emailAccountDescription} semble contenir votre UID.\nNous ajoutons le lien de votre signature."
			/usr/libexec/PlistBuddy ${plistFileMail} -c "print :SignatureSelectionMethods:${emailAccountUuid}" > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute avec PlistBuddy l'entrée :SignatureSelectionMethods:${emailAccountUuid} SelectedOnly dans ${plistFileMail}"
				/usr/libexec/PlistBuddy ${plistFileMail} -c "add :SignatureSelectionMethods:${emailAccountUuid} string"
				/usr/libexec/PlistBuddy ${plistFileMail} -c "set :SignatureSelectionMethods:${emailAccountUuid} SelectedOnly"
			else
				[[ ${verbosity} -eq "1" ]] && echo -e "\nVotre fichier ${plistFileMail} contient déjà :SignatureSelectionMethods:${emailAccountUuid} SelectedOnly."
			fi
		fi
	done
fi

# On ajoute l'information dans plistFileMail > SignaturesSelected (signature sélectionnée par défaut)
# On teste si <key>SignaturesSelected</key> existe
/usr/libexec/PlistBuddy ${plistFileMail} -c "print :SignaturesSelected" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	[[ ${verbosity} -eq "1" ]] && echo -e "\nOn ajoute avec PlistBuddy l'entrée :SignaturesSelected dans ${plistFileMail}."
	/usr/libexec/PlistBuddy ${plistFileMail} -c "add :SignaturesSelected dict"
fi	
for emailAccountUuid in ${listeEmailAccountsPlist}
do
	addDefaultSignature=0
	emailAccountDescription=$(/usr/libexec/PlistBuddy ${accountSignaturesMapPlist} -c "print :${emailAccountUuid}:AccountURL" | sed "s/ //g" )
	# Test si la signature est déjà enregistréee
	/usr/libexec/PlistBuddy ${plistFileMail} -c "print :SignaturesSelected" | sed "s/ //g" | grep '^[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*=[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*$' | grep ${emailAccountUuid}=${UUID} > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		[[ ${verbosity} -eq "1" ]] && echo -e "\nL'entrée :SignaturesSelected ${emailAccountUuid}=${UUID} est déjà renseignée dans le fichier ${plistFileMail}."
	else

		if [[ ${modeMapping} == "UID" ]]; then
			# On teste si la description contient d'UID de l'utilisateur
			echo ${emailAccountDescription} | grep ${userUid} > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				[[ ${verbosity} -eq "1" ]] && echo -e "\nVous avez sélectionné l'option \"-e ${modeMapping}\" et le compte email ${emailAccountDescription} semble contenir votre UID.\nNous ajoutons le lien de votre signature par défaut dans le fichier ${plistFileMail}."
				addDefaultSignature=1
			fi
		fi
		if [[ ${modeMapping} == "ALL" ]]; then
			addDefaultSignature=1
		fi

		if [[ ${addDefaultSignature} -eq 1 ]]; then
			# On teste si :SignaturesSelected ${emailAccountUuid} et s'il faut juste le modifier, ou le créer complètement
			/usr/libexec/PlistBuddy ${plistFileMail} -c "print :SignaturesSelected:${emailAccountUuid}" > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				[[ ${verbosity} -eq "1" ]] && echo -e "\nOn modifie l'entrée :SignaturesSelected ${emailAccountUuid}=${UUID} dans le fichier ${plistFileMail}."
				/usr/libexec/PlistBuddy ${plistFileMail} -c "set :SignaturesSelected:${emailAccountUuid} ${UUID}"
			else
				[[ ${verbosity} -eq "1" ]] && echo -e "\nOn crée l'entrée :SignaturesSelected ${emailAccountUuid}=${UUID} dans le fichier ${plistFileMail}."
				/usr/libexec/PlistBuddy ${plistFileMail} -c "add :SignaturesSelected:${emailAccountUuid} string"
				/usr/libexec/PlistBuddy ${plistFileMail} -c "set :SignaturesSelected:${emailAccountUuid} ${UUID}"
			fi
		fi
	fi
done

# On vérouille le fichier XML
chflags uchg ${accountSignaturesMapPlist}
chflags uchg ${plistFileMail}

alldone 0