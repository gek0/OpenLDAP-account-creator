#!/usr/bin/env bash
# create LDAP account for new employees
#set -x             # comment out for debugging purposes
set -u              # exit if there are unset variables
set -o errexit      # exit on error

# LDAP flags
# ---------------------------
# -L | Search results are display in LDAP Data Interchange Format detailed in ldif(5).
#           A single -L restricts the output to LDIFv1. A second -L disables comments.
#           A third -L disables printing of the LDIF version.
#           The default is to use an extended version of LDIF.
# -n | Show what would be done, but don't actually perform the search. Useful for debugging in conjunction with -v.
# -v | Run in verbose mode, with many diagnostics written to standard output.
# -x | Use simple authentication instead of SASL.
# -S | Sort the entries returned based on attribute. The default is not to sort entries returned.
#           If attribute is a zero-length string (""), the entries are sorted by the components of their Distinguished Name.
# -D | binddn
#       Use the Distinguished Name binddn to bind to the LDAP directory. For SASL binds, the server is expected to ignore this value.
# -H | ldapuri
#       Specify URI(s) referring to the ldap server(s); a list of URI, separated by whitespace or commas is expected; only the protocol/host/port fields are allowed.

# variable definitions
ldap_server_url=''                                  # example 'ldaps://server.example.com:636'
bind_base_dn=''                                     # example 'cn=admin,dc=example,dc=com'
base_dn=''                                          # example 'dc=example,dc=com'
destination_dn=''                                   # example 'ou=People,${base_dn}'
ldapsearch_extra_attributes='-LLL'                  # example '-v -n -LLL' for debugging and showing what query is actually executed
password_allowed_chars='A-Za-z0-9_'                 # example 'A-Za-z0-9_', allow more chars for password strength if needed
password_lenght=10                                  # use maximum of 40 to be safe with all hashes
salt_lenght=5                                       # 5 should be reasonable length
hashing_algorithm='ssha'                            # possible choices are 'cleartext', 'md5', 'crypt' or 'ssha'
user_home_dir='/home/'                              # example '/home/users/${username}' or '/home/${username}'
user_login_shell='/bin/false'                       # example '/bin/false' or '/bin/bash'
user_email_from=''                                  # example 'admin@example.com'
user_email_subject=''                               # example 'Account credentials', email_body is defined later (if needed)
declare -a uid_to_exclude=(0 6005)                  # space separated uids / if needed, else leave empty | exclude users like root, adm...who can have big uid-s

# functions definitions
function getMaxUid() {
    # get highest UID - new user needs +1
    declare -a all_uids=("$( ldapsearch "${ldapsearch_extra_attributes}" -H "${ldap_server_url}" -D "${bind_base_dn}" -w "${ldap_server_password}" -b "${base_dn}" "(uidNumber=*)" uidNumber -S uidNumber | grep uidNumber | cut -d : -f 2 | sed -e 's/^[[:space:]]*//')")

    # comment out for debugging
    # echo -e "${all_uids[@]}"

    # check if array contains uids to delete
    if [[ ${#uid_to_exclude[@]} -ne 0 ]]
    then
        for exc in "${uid_to_exclude[@]}"
        do
            all_uids=( ${all_uids[@]/$exc/} )
        done
    fi

    # check for largest uid in array
    max_uid=0
    for i in "${all_uids[@]}"
    do
        if [[ ${i} -gt ${max_uid} ]]
        then
            max_uid=${i}
        fi
    done

    new_user_uid=$(( max_uid + 1 ))
    echo -e "Biggest UID is: '${max_uid}', so using UID: '${new_user_uid}' for new user.\n"
}

genPasswd() {
    # generate strong password for new user
    password="$(tr -dc "${password_allowed_chars}" < /dev/urandom | head -c "${password_lenght}" | xargs)"
    salt="$(tr -dc "${password_allowed_chars}" < /dev/urandom | head -c "${salt_lenght}" | xargs)"
    new_user_password="${password}${salt}"

    if [[ "$(which slappasswd)" == "" ]]
    then
        echo -e "\nHashing utility 'slappasswd' not available. Using clear text password..."
        new_user_password_hash="${new_user_password}"
    else
        # hash it to selected algorithm
        case "${hashing_algorithm}" in
            'cleartext')
                    echo -e "\nUsing clear text password without hashing algorithm."
                    new_user_password_hash="${new_user_password}"
                    ;;

            'md5')
                    echo -e "\nUsing 'MD5' as password algorithm."
                    new_user_password_hash=$(slappasswd -h {MD5} -s "${new_user_password}")
                    ;;

            'crypt')
                    echo -e "\nUsing 'Crypt' as password algorithm."
                    new_user_password_hash=$(slappasswd -h {CRYPT} -s "${new_user_password}")
                    ;;

            'ssha')
                    echo -e "\nUsing 'SSHA' as password algorithm."
                    new_user_password_hash=$(slappasswd -h {SSHA} -s "${new_user_password}")
                    ;;

            *)
                    echo -e "\nWrong or no hashing algorithm selected, using insecure clear text password..."
                    new_user_password_hash="${new_user_password}"
                    ;;
        esac
    fi
}

getUserInfo() {
    # get all info needed for account creation
    read -p "First and last name (only english alphabet): " new_user_full_name
    new_user_firstname="$(echo "${new_user_full_name}" | awk '{ print $1 }')"
    new_user_lastname="$(echo "${new_user_full_name}" | awk '{ print $NF }')"

    read -p "Email: " new_user_email
    read -p "Username: " new_user_username
}

addUser() {
    # use admin provided data do create user account data
    echo "dn: cn=${new_user_full_name},${destination_dn}"
    echo "mail: ${new_user_email}"
    echo "uid: ${new_user_username}"
    echo "cn: ${new_user_full_name}"
    echo "gn: ${new_user_firstname}"
    echo "sn: ${new_user_lastname}"
    echo "objectClass: inetOrgPerson"
    echo "objectClass: posixAccount"
    echo "objectClass: top"
    echo "userPassword: ${new_user_password_hash}"
    echo "uidNumber: ${new_user_uid}"
    echo "gidNumber: ${new_user_uid}"
    echo "loginShell: ${user_login_shell}"
    echo "homeDirectory: ${user_home_dir}${new_user_username}"
}

printUserInfo() {
    # return all necessary info to admin
    echo -e "\n----------- Credentials for user '${new_user_username}' -----------"
    echo -e "Email: \t\t\t${new_user_email}"
    echo -e "Username: \t\t${new_user_username}"
    echo -e "Password: \t\t${new_user_password}"
    echo -e "Password hash:  \t${new_user_password_hash}"
    echo -e "Home directory: \t${user_home_dir}${new_user_username}"
    echo -e "Login shell: \t\t${user_login_shell}"
    echo -e "-------------------------------------------------------\n"
}

setupEmail() {
    # check if mail utility is installed
    if [[ "$(which mail)" == "" ]]
    then
        sudo apt-get update
        sudo apt-get -y install mailutils

        echo -e "\nMail service installed. Configure if necessary.\n"
    else
        echo -e "\nUtility tool 'mailutils' already installed.\n"
    fi
}

sendInfoToEmail() {
    # send all necessary info to user
    read -p "Send information to user email (y/n): " send_email

    case "${send_email}" in
        'y')
            setupEmail
            echo -e "Sending this email to user...\n"

            # define email body
            user_email_body='<!doctype html>
            <html lang=en>
            <head>
            <meta charset=utf-8>
            </head>
            <body>
                <p>Personalized text here, account credentials and other info sent to employe...
            </body>
            </html>'

            echo -e "------------------\n${user_email_body}\n------------------"
            echo -e "${user_email_body}" | mail -a "Content-Type: text/html; charset=UTF-8" -a "From: ${user_email_from}" -a "MIME-Version: 1.0" -s "${user_email_subject}" "${new_user_email}" || echo -e "Mail could not be sent!"
            ;;

        'n')
            echo -e "Remember to give your user credentials."
            ;;

        *)
            echo -e "Remember to give your user credentials."
    esac
}

# start with the main program
echo -e "#######################################"
echo -e "### Welcome to LDAP account creator ###"
echo -e "#######################################\n"

read -s -p "LDAP server password: " ldap_server_password
echo -e "\nConnection check in progress..."

# test connection with LDAP server
if [[ "$(ldapwhoami -H "${ldap_server_url}" -D "${bind_base_dn}" -w "${ldap_server_password}")" ]]
then
    echo -e "\nBind to LDAP server successful."
else
    echo -e "\nBind to LDAP server failed, check credentials."
    exit 99
fi

# check if ldapsearch utility is installed
if [[ "$(which ldapsearch)" == "" ]]
then
    sudo apt-get update
    sudo apt-get -y install libnss-ldap libpam-ldap nscd ldap-utils slapd # slapd is needed for SSHA hashing algorithm
    sudo dpkg-reconfigure libnss-ldap

    echo -e "Configure /etc/ldap/ldap.conf with LDAP server data if not already and restart 'nscd' service."
    echo -e "Exiting. Return after setting the configuration for LDAP server."
    exit 98
else
    echo -e "Utility tool 'ldapsearch' already installed.\n"
fi

# call main functions
getMaxUid

getUserInfo

genPasswd

# add user to LDAP...
if [[ "$(addUser | ldapadd -H "${ldap_server_url}" -w "${ldap_server_password}" -D "${bind_base_dn}")" ]]
then
    echo -e "\nUser added to LDAP successfully."
else
    echo -e "\nUnable to add user to LDAP, check server log for more info."
    exit 97
fi

printUserInfo

sendInfoToEmail

echo -e "\nAll done. Bye"

exit 0