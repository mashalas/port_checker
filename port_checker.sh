#!/usr/bin/env sh

NETCAT=nc
MAIL_PROGRAM=mailx
PROTOCOL_TCP=TCP
PROTOCOL_UDP=UDP

usage()
{
  echo 'SYNOPSIS'
  echo '        port_checker.sh [options] host port'
  echo ' '
  echo 'DESCRIPTION'
  echo '        This script is designed to check the availability of network ports and perform actions depending on whether the port is open or not.'
  echo '        Actions are:'
  echo '          * write information to a file;'
  echo '          * execute an operating system command;'
  echo '          * send an email message;'
  echo ' '
  echo 'OPTIONS'
  echo '        -h | --help                       print this help.'
  echo '        -v | --verbose                    verbose mode.'
  echo '        -c | --comment                    text comment to be added to message for log-file and email.'
  echo '        -u | --UDP | --udp                check UDP-port insted of TCP.'
  echo ' '
  echo '        --log-on-success <filename>       write to file message abount success connection.'
  echo '        --exec-on-success <command>       execute command if connection successfully.'
  echo '        --mail-on-success <receiver>      send email to receiver if connection successfully (multiple parameter - may be specified several times for sending to several receivers).'
  echo '        --attach-on-success <filename>    attach the file to letter if connection successfully.'
  echo ' '
  echo '        --log-on-fail <filename>          write to file message abount failed connection.'
  echo '        --exec-on-fail <command>          execute command if connection failed.'
  echo '        --mail-on-fail <receiver>         send email to receiver if connection failed (multiple parameter - may be specified several times for sending to several receivers).'
  echo '        --attach-on-fail <filename>       attach the file to letter if connection failed.'
}

notify()
{
  # вне функции должны быть определены переменные: message, log_file, exec_command
  # если не нужно записывать в файл - там будет минус
  # если не нунжно выполнять команду - там будет минус
  receivers=(${@})
  #echo message: $message
  #echo log_file: $log_file
  #echo exec_command: $exec_command
  #echo receivers: ${receivers[@]}

  if [ $verbose -gt 0 ]; then echo $message ; fi

  if [ ! -z $log_file ]
  then
    if [ "$log_file" != "-" ]
    then
      echo $message >> $log_file
    fi
  fi
  if [ ! -z $exec_command ]
  then
    if [ "$exec_command" != "-" ]
    then
      eval $exec_command
    fi
  fi

  for one_receiver in ${receivers[@]}
  do
    #echo MAILTO: $one_receiver
    #echo "$message" | $MAIL_PROGRAM -s "$message" $one_receiver
    cmd="$MAIL_PROGRAM -s \"$message\""
    if [ "$attach" != "-" ]; then cmd="$cmd -a $attach"; fi
    cmd="$cmd $one_receiver"
    eval $cmd
  done
}

#-----------------------------------------main------------------------------------------
if [ -z $E_OPTERROR ]; then export E_OPTERROR=65; fi
if [ -z $E_PROGRAM_NOT_FOUND ]; then export E_PROGRAM_NOT_FOUND=127; fi

if [ $# -eq 0 ]
then
  # файл вызван без указания параметров
  usage
  exit $E_OPTERROR
fi

# проверить, что netcat установлен в системе
$NETCAT --help > /dev/null 2>&1
if [ $? -eq 127 ]
then
  echo Cannot find netcat as \"$NETCAT\"
  exit $E_PROGRAM_NOT_FOUND
fi
# проверить, что почтовая программа определённая в константе MAIL_PROGRAMA установлен в системе
which $MAIL_PROGRAM > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo Cannot find mail-program as \"$MAIL_PROGRAM\"
  exit $E_PROGRAM_NOT_FOUND
fi

log_on_success=-
exec_on_success=-
mail_on_success=()
attach_on_success=-

log_on_fail=-
exec_on_fail=-
mail_on_fail=()
attach_on_fail=-

verbose=0
comment=-
protocol=$PROTOCOL_TCP
positional=($0)  # нулевым позиционным параметром идёт имя вызываемого скрипта

while [ $# -gt 0 ]
do
  case ${1} in
    # --- логические флаги ---
    -h | --help | -help )
      usage
      exit
      ;;
    -v | --verbose ) verbose=1 ;;
    -u | --udp | --UDP ) protocol=$PROTOCOL_UDP ;;

    # --- именованные параметры со значением параметра ---
    -c | --comment )
      comment=$2
      shift
      ;;

    --log-on-success )
      log_on_success=$2
      shift
      ;;
    --exec-on-success )
      exec_on_success=$2
      shift
      ;;
    --mail-on-success )
      mail_on_success+=($2)
      shift
      ;;
    --attach-on-success )
      attach_on_success=$2
      shift
      ;;

    --log-on-fail )
      log_on_fail=$2
      shift
      ;;
    --exec-on-fail )
      exec_on_fail=$2
      shift
      ;;
    --mail-on-fail )
      mail_on_fail+=($2)
      shift
      ;;
    --attach-on-fail )
      attach_on_fail=$2
      shift
      ;;

    -* )
      # необрабатываемый именованный параметр
      echo "ERROR: unknown named argument: $1"
      exit $E_OPTERROR
      ;;

    # --- позиционные параметры (нулевым идёт имя скрипта) ---
    * ) positional+=($1) ;;
  esac
  shift
done

host=${positional[1]}
port=${positional[2]}
if [ -z $host ]
then
  echo ERROR!!! host name is not specified
  exit 1
fi
if [ -z $port ]
then
  echo ERROR!!! port number is not specified
  exit 1
fi

if [ $verbose -gt 0 ]
then
  echo --- params: ---
  echo log_on_success: $log_on_success
  echo exec_on_success: $exec_on_success
  echo mail_on_success: ${mail_on_success[@]}

  echo log_on_fail: $log_on_fail
  echo exec_on_fail: $exec_on_fail
  echo mail_on_fail: ${mail_on_fail[@]}

  echo verbose: $verbose
  echo host: $host
  echo port: $port
  echo protocol: $protocol
  #echo positional: ${positional[@]}
  echo --- end of params: ---
fi

export message="[20`date '+%y-%m-%d %H:%M:%S'`]"
if [ "$comment" != "-" ]; then export message="$message ${comment}:" ; fi

cmd=$NETCAT
if [ $verbose -gt 0 ]; then cmd="$cmd -v"; fi
if [ "$protocol" == "$PROTOCOL_UDP" ]; then cmd="$cmd -u"; fi
cmd="$cmd -z -4 $host $port"
# -v  verbose
# -z  Perform  port  scan  (сразу завершить работу, если соединение удалось, иначе будет висеть подключенным)
# -4  Force nc to use IPv4 addresses only (если указать сетевое имя и для этого имени есть IP6, будет две попытки подключения)

if [ $verbose -gt 0 ]; then echo "Checking command: $cmd" ; fi
eval $cmd
retcode=$?; export retcode
export attach
if [ $retcode -eq 0 ]
then
  # порт открыт
  export message="$message successfully connected to ${host}:${port} by ${protocol}-protocol."
  export log_file=$log_on_success
  export exec_command=$exec_on_success
  export attach=$attach_on_success
  notify ${mail_on_success[@]} # т.к. сообщение содержит пробелы, то оно разбивается на элементы массива, даже если передавать в кавычках
else
  # не удалось установить соединение
  export message="$message cannot connect to ${host}:${port} by ${protocol}-protocol"
  export log_file=$log_on_fail
  export exec_command=$exec_on_fail
  export attach=$attach_on_fail
  notify ${mail_on_fail[@]} # т.к. сообщение содержит пробелы, то оно разбивается на элементы массива, даже если передавать в кавычках
fi
exit $retcode
