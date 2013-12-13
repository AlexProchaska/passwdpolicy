#!/usr/bin/ksh
###################################################################
#
# passwdpolicy.ksh
#
# This script will set the password expiration and complexity
# rules on an Ubuntu system. It assumes local PAM authentication
# and will edit /etc/pam.d/common-password and /etc/login.defs
#
###################################################################
#
# Input variables - set to 0 to leave unrestricted
#
minlength=8                          # Minimum acceptable password length
mindigit=2                           # Minimum number of digits
minsymbol=1                          # Minimum number of non-alphanumeric characters
minupper=1                           # Minimum number of upper-case letters
minlower=1                           # Minimum number of lower-case letters
numretry=3                           # Maximum number of prompts before returning with error
mindif=3                             # Minimum number of characters that must differ from previous password
maxdays=90                           # Number of days before requiring password change
mindays=3                            # Minimum number of days allowed required between password change attempts
warndays=7                           # Number of days warning given before password expiration
#
# File locations
#
logfile=passwdpolicy.log             # Filename for log file
tempfile=passwdpolicy.tmp            # Filename for temp file
pamfile=/etc/pam.d/common-password   # Full path to PAM common-password conf file
loginfile=/etc/login.defs            # FUll path to login conf file
#
# Do not edit below this line #####################################
#
echo $(date)" - Starting passwdpolicy.ksh" | tee $logfile
#
# Sanity checks
#
if [[ $USER != "root" ]];then # NOT ROOT
  echo "Exiting.  Not root." | tee -a $logfile
  echo $(date)" - Failed to complete passwdpolicy.ksh" | tee -a $logfile
  exit
fi
if [[ -z $(lsb_release -d | grep Ubuntu) ]];then # NOT UBUNTU
  echo "Exiting.  Not Ubuntu." | tee -a $logfile
  echo $(date)" - Failed to complete passwdpolicy.ksh" | tee -a $logfile
 exit
fi
if [[ -w $pamfile ]] && [[ -s $pamfile ]];then
  cp $pamfile $PWD/common-password.backup
else # BAD COMMON-PASSWORD
  echo "Exiting.  $pamfile is absent, unwriteable, or empty" | tee -a $logfile
  echo $(date)" - Failed to complete passwdpolicy.ksh" | tee -a $logfile
  exit
fi
if [[ -w $loginfile ]] && [[ -s $loginfile ]];then
  cp $loginfile $PWD/login.defs.backups
else # BAD LOGIN.DEFS
  echo "Exiting.  $loginfile is absent, unwriteable, or empty" | tee -a $logfile
  echo $(date)" - Failed to complete passwdpolicy.ksh" | tee -a $logfile
  exit
fi
#
# Install pam_cracklib
#
dpkg -s libpam-cracklib > $tempfile 2>&1
if [[ -n $(grep "not installed" $tempfile) ]];then # pam_cracklib not installed
  if [[ -n $(apt-get check | grep unmet) ]];then   # unmet dependencies need to be addressed first
    echo "Exiting.  Cannot install libpam-cracklib.  Unmet dependencies." | tee -a $logfile
    echo $(date)" - Failed to complete passwdpolicy.ksh" | tee -a $logfile
    exit
  else # INSTALL
    echo "Y" | apt-get install libpam-cracklib | tee -a $logfile
  fi
fi
#
# Set complexity policy
#
pam-auth-update --remove cracklib --force | tee -a $logfile
sed -e "s/obscure\ sha512/obscure\ use_authtok\ try_first_pass\ sha512/g" $pamfile > $tempfile
cracklib_string=$(echo -e "password\trequisite\t\t\tpam_cracklib.so")
if [[ $numretry != 0 ]];then
  cracklib_string=$cracklib_string" retry="$numretry
fi
if [[ $minlength != 0 ]];then
  cracklib_string=$cracklib_string" minlen="$minlength
fi
if [[ $mindif != 0 ]];then
  cracklib_string=$cracklib_string" difok="$mindif
fi
if [[ $mindigit != 0 ]];then
  cracklib_string=$cracklib_string" dcredit=-"$mindigit
fi
if [[ $minsymbol != 0 ]];then
  cracklib_string=$cracklib_string" ocredit=-"$minsymbol
fi
if [[ $minupper != 0 ]];then
  cracklib_string=$cracklib_string" ucredit=-"$minupper
fi
if [[ $minlower != 0 ]];then
  cracklib_string=$cracklib_string" lcredit=-"$minlower
fi
sed -i "/pam_unix.so/i \
$cracklib_string" $tempfile
cp $tempfile $pamfile
#
# Set expiration policy
#
if [[ $maxdays != 0 ]];then
  sed -i "/^PASS_MAX_DAYS/c\PASS_MAX_DAYS\t$maxdays" $loginfile
fi
if [[ $mindays != 0 ]];then
  sed -i "/^PASS_MIN_DAYS/c\PASS_MIN_DAYS\t$mindays" $loginfile
fi
if [[ $warndays != 0 ]];then
  sed -i "/^PASS_WARN_AGE/c\PASS_WARN_AGE\t$warndays" $loginfile
fi
#
echo $(date)" - Successfully finished passwdpolicy.ksh" | tee -a $logfile
