#!/bin/bash

##### Estilos de texto #####

TEXT_YELLOW=$(tput setaf 3) # Hace que el texto sea amarillo
TEXT_BLUE=$(tput setaf 4) # Hace que el texto sea azul
TEXT_RESET=$(tput sgr0) # Restablece el formato de texto a los valores predeterminados

##### Constantes de utilidad### 

TITLE="Información del sistema para $HOSTNAME" # Nombre del host de la máquina.
DATE=$(date +"%x %r%Z") # Fecha y hora actual.
TIME_STAMP="Actualizada el $DATE por $USER" # Muestra la fecha, hora y usuario que ha actualizado la información.

##### Opciones #####

READLIST=0
READPROG=0
g_option=false
gc_option=false
ge_option=false


##### Funciones #####

# Función para mostrar el menú de ayuda. 
usage() 
{
  echo "Usage: ./scdebug.sh  [-h] [-sto arg] [-v | -vall] [-k] [prog [arg …] ] [-nattch progtoattach …] [-pattch pid1 … ]" 
}

# Función que se encarga de crear en segundo plano un proceso con el comando strace.
STRACE(){

  strace $stovar $@ 2>&1 | tee -a scdebug/$1/trace_$uuid.txt  
}

# Función que se encarga de 
programa() {
  CHECK $1

  uuid=$(uuidgen)
  echo "strace $stovar  -o scdebug/$1/trace_$uuid.txt $@" 
  STRACE $1 &
}

STRACE_NATTCH(){
  strace $stovar -p $PID -o scdebug/$1/trace_$uuid.txt| tee -a scdebug/$1/trace_$uuid.txt
}

nattch(){  

  CHECK $1
  PID=$( ps aux | grep $1 | grep $USER | sort -k 4 | tail -n 4 | head -n 1 | tr -s ' ' | cut -d ' ' -f2  )
  uuid=$(uuidgen)
  STRACE_NATTCH $1 $PID &
}

trace(){
  ps_output=$(ps -U $USER -o pid,comm --no-header)

  # Recorrer la lista de procesos y verificar el atributo TracerPid
  while read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    process_name=$(echo "$line" | awk '{print $2}')

    # Verificar si el proceso está siendo trazado
    if [ -f "/proc/$pid/status" ]; then
      tracer_pid=$(awk -F'\t' '/TracerPid/{print $2}' "/proc/$pid/status")
      if [ "$tracer_pid" -ne 0 ]; then
        tracer_name=$(awk -F'\t' '/Name/{print $2}' "/proc/$tracer_pid/status")
        echo "${TEXT_GREEN} Proceso bajo trazado (PID, Nombre): $pid, $process_name ---- Proceso trazador (PID, Nombre): $tracer_pid, $tracer_name ${TEXT_RESET}"
        #echo "Proceso trazador (PID, Nombre): $tracer_pid, $tracer_name"
        echo "-------------------------"
      else 
        echo "${TEXT_RED} Proceso bajo trazado (PID, Nombre): $pid, $process_name ---- Proceso trazador (PID, Nombre): 0, Ninguno${TEXT_RESET}"
        #echo "Proceso trazador (PID, Nombre): 0, Ninguno"
        echo "-------------------------"
      fi
    fi
  done <<< "$ps_output"
}

KILL(){ # funciona en maquina ajena, pero no en la local
  ps_output=$(ps -U $USER -o pid,comm --no-header)

  while read -r line; do
    pid=$(echo "$line" | awk '{print $1}')

    # Verificar si el proceso está siendo trazado
    if [ -f "/proc/$pid/status" ]; then
      tracer_pid=$(awk -F'\t' '/TracerPid/{print $2}' "/proc/$pid/status")
      #echo "entra en KILL"
      if [ "$tracer_pid" -ne 0 ]; then
        #echo "kill -s SIGKILL $tracer_pid"
        kill -s SIGKILL $tracer_pid &> /dev/null # si pongo aqui el 2>&1 explota
        #echo "kill -s SIGKILL $pid"
        kill -s SIGKILL $pid &> /dev/null # aqui tambien
      fi
    fi
  done <<< "$ps_output"

}

# Función que se encarga de comprobar si existe la carpeta scdebug y scdebug/$1, así como qué procesos se están ejecutando.
CHECK(){
  if [ $# -eq 0 ]; then
    echo "La función 'prog' fue llamada sin argumentos."
    exit 1
  else
      echo "La función 'prog' fue llamada con argumentos: $@"
  fi

  if [ -d "scdebug" ]; then # comprobar que la carpeta scdebug existe
    echo "La carpeta scdebug existe."
  else
    echo "La carpeta scdebug no existe."
    echo "mkdir scdebug"
    $(mkdir scdebug )
  fi

 if [ -d "scdebug/$1" ]; then # comprobar que la carpeta scdebug/$1 existe
   echo "La carpeta $1 existe."
 else
   echo "La carpeta $1 no existe."
   echo "mkdir scdebug/$1"
   $(mkdir scdebug/$1 )
 fi
}

ejecutable_pattch(){
  strace $stovar -p $1 -o scdebug/$1/trace_$uidd.txt | tee -a scdebug/$1/trace_$uidd.txt # ejecutar el comando
}

PATTCH(){
  CHECK $1
  uuid=$(uuidgen)
  #$(strace $stovar -p $1 -o scdebug/$1/trace_$uuid.txt &)
  ejecutable_pattch $1 &
}

VISUALIZE(){
  directorio="scdebug/$1"


  if [ -d "$directorio" ]; then
    archivo_mas_reciente=$(ls -t "$directorio" | head -1)
    
    if [ -n "$archivo_mas_reciente" ]; then
      modi_date=$(stat -c %y "$directorio/$archivo_mas_reciente")

      echo "=============== ${TEXT_GREEN}COMMAND: $1 ${TEXT_RESET}============================================================="
      echo "=============== ${TEXT_GREEN}TRACE FILE: $archivo_mas_reciente ${TEXT_RESET}================="
      echo "=============== ${TEXT_GREEN}TIME: $modi_date ${TEXT_RESET}=================================="

      cat "$directorio/$archivo_mas_reciente"
    else
      echo "${TEXT_RED}El directorio está vacío o no contiene archivos.${TEXT_RESET}"
    fi
  else
    echo "${TEXT_RED}El directorio $directorio no existe.${TEXT_RESET}"
  fi
}

VALL(){
  directorio="scdebug/$1"
  for file in "$directorio"/*; do
    if [ -f "$file" ]; then
      modi_date=$(stat -c %y "$file")
      echo "=============== ${TEXT_GREEN}COMMAND: $1 ${TEXT_RESET}============================================================="
      echo "=============== ${TEXT_GREEN}TRACE FILE: $file ${TEXT_RESET}==="
      echo "=============== ${TEXT_GREEN}TIME: $modi_date ${TEXT_RESET}=================================="

    fi
  done
}

STOP(){ 
  echo -n traced_$1 > /proc/$$/comm


  #echo "kill -SIGSTOP $$"
  kill -SIGSTOP $$

  # echo "exec $listaProg"
  exec $listaProg

}

##### pruebas de ejecucion
check_uuidgen_availability() {
    if command -v uuidgen &> /dev/null; then
        echo "uuidgen está disponible en el sistema."
    else
        echo "uuidgen no está disponible en el sistema."
        exit 1
    fi
}

check_strace_availability() {
    if command -v strace &> /dev/null; then
        echo "strace está disponible en el sistema."
    else
        echo "strace no está disponible en el sistema."
        exit 1
    fi
}

llamada(){
  #echo "llamada $1"
  #echo "strace -p $1 -o scdebug/$1/trace_$uidd.txt | tee -a scdebug/$1/trace_$uidd.txt"
  strace -p $1 -o scdebug/$1/trace_$uuidd.txt /dev/null
}

funtion_G(){ #debe funcionar, no está comprobado

  lista_g=$(ps | grep traced_ | tr -s ' ' | cut -d ' ' -f2 | tr -s '\n' ' ')
  #echo $lista_g

  for i in $lista_g; do
    CHECK $i
    uuid=$(uuidgen)
    #echo "uidd es $uuid"
    llamada $i &
    sleep 1
    kill -SIGCONT $i
  done

}


llamada2(){
  #echo "llamada $1"
  #echo "strace -p $1 -c -U | tee -a scdebug/$1/trace_$uuid.txt"
  
  tabla=$(strace -p $1 -c -U name,max-time,total-time,calls -S max-time 2>&1)
  echo "$tabla"
  # pillar la terecra fila de la tabla
  echo "-------------------------"
  echo $(echo "$tabla" | head -n 4 | tail -n 1)
  #echo "strace -p $1 -c -U | tee -a scdebug/$1/trace_$uuid.txt | tail -n 3 | head -n 1"
  
}

funtion_GC(){ #debe funcionar, no está comprobado

  lista_g=$(ps | grep traced_ | tr -s ' ' | cut -d ' ' -f2 | tr -s '\n' ' ')
  #echo $lista_g

  for i in $lista_g; do
    #echo ${TEXT_GREEN} "Proceso $i" ${TEXT_RESET}
    CHECK $i
    uuid=$(uuidgen)
    #echo "${TEXT_GREEN}uidd es $uuid ${TEXT_RESET}"
    echo "${TEXT_GREEN}Proceso $i "
    llamada2 $i &
    echo "${TEXT_RESET}"
    echo "$tabla"
    sleep 1
    kill -SIGCONT $i 
  done

}

llamada3(){

  #echo "llamada $1"
  #echo "strace -p $1 -c -U | tee -a scdebug/$1/trace_$uuid.txt"
  
  tabla=$(strace -p $1 -c -U name,max-time,total-time,calls,errors -S errors 2>&1)
  echo "$tabla"
  # pillar la terecra fila de la tabla
  echo "-------------------------"
  echo $(echo "$tabla" | head -n 4 | tail -n 1)
  #echo "strace -p $1 -c -U | tee -a scdebug/$1/trace_$uuid.txt | tail -n 3 | head -n 1"
  
}

funtion_GE(){
  
  lista_g=$(ps | grep traced_ | tr -s ' ' | cut -d ' ' -f2 | tr -s '\n' ' ')

  for i in $lista_g; do
    CHECK $i
    uuid=$(uuidgen)
    echo "${TEXT_GREEN}Proceso $i "
    llamada3 $i &
    echo "${TEXT_RESET}"
    echo "$tabla"
    sleep 1
    kill -SIGCONT $i 
  done
}

# En el caso de que no se pase ningún argumento, se muestra el menú de ayuda.
if [ $# -eq 0 ]; then
  echo "Debe añadir al menos un argumento."
  usage
  exit 1
fi

# Bucle para leer los argumentos pasados por teclado.
while [ "$1" != "" ]; do
    case $1 in
        -h )           
            usage
            exit
            ;;         
        -sto )   
          stovar="$2"
          echo "sto es $stovar"
          ;;   
        -nattch )  
          if [ "$2" == "" ]; then
          echo "Se esperaban argumentos para -nattch ( progtoattach1 ... ))"
            usage
            exit 1
          fi
          while [ "$2" != "-h" ] && [ "$2" != "prog" ] && [ "$2" != "-sto" ] && [ "$2" != "" ] && [ "$2" != "-pattch" ] && [ "$2" != "-k" ]; do
            nattch "$2" 
            shift
          done
            ;;
        -k )  
          KILL
          shift
          ;;
        -pattch )  
          if [ "$2" == "" ]; then
            echo "Se esperaban argumentos para -pattch ( pid1 ... ))"
            usage
            exit 1
          fi
          while [ "$2" != "-h" ] && [ "$2" != "prog" ] && [ "$2" != "-sto" ] && [ "$2" != "" ] && [ "$2" != "-nattch" ] && [ "$2" != "-k" ]; do
            PATTCH "$2"
            shift
          done
          ;;
        -v )
            # if [ "$3" != "" ]; then
            #   echo "No se esperaban argumentos extra para -v"
            #   exit 1
            # fi
          if [ "$2" == "" ]; then
            echo "Se esperaban argumentos para -v ( prog1 ... ))"
            usage
            exit 1
          fi
          while [ "$2" != "-h" ] && [ "$2" != "prog" ] && [ "$2" != "-sto" ] &&  [ "$2" != "" ] ; do
            VISUALIZE "$2"
            shift
          done
          exit 0
          ;;
        -vall )
            if [ "$2" == "" ] ; then
              echo "Se esperaban argumentos para -vall"
              exit 1
            fi
          while [ "$2" != "-h" ] && [ "$2" != "prog" ] && [ "$2" != "-sto" ] &&  [ "$2" != "" ] ; do
            VALL "$2"
            shift
          done
            exit 0
            ;;
        -S )  
          if [ "$2" == "" ]; then
            echo "Se esperaba un argumento para -S ( prog1 [arg1 ...] ))"
            echo "scdebug [-h] [-k] -S commName prog [arg...]"
            exit 1
          fi
            STOP "$2"
            shift
          ;;
        -g )
          g_option=true
          ;;
        -gc )
          gc_option=true
          ;;
        -ge )
          ge_option=true
          ;;

        * ) if [ "$READLIST" -ne 1 -a "$READPROG" -ne 2 ]; then
		      READPROG=1
		      listaProg+="$1 "
            elif [ "$READLIST" -eq 1 ]; then
                lista+="$1 "
            else
                echo "Argumento no reconocido: $1"
                usage
                exit 1
            fi
          ;;             
    esac
    shift
done

if [[ $g_option == true && ($gc_option == true || $ge_option == true) ]] ||
   [[ $gc_option == true && ($g_option == true || $ge_option == true) ]] ||
   [[ $ge_option == true && ($g_option == true || $gc_option == true) ]]; then
  echo "Debes especificar solo una de las opciones -g, -gc o -ge"
  usage
  exit 1
fi

if [ $g_option == true ]; then
  echo "Se ha seleccionado la opción -g."
  funtion_G 
elif [ $gc_option == true ]; then
  echo "Se ha seleccionado la opción -gc."
  funtion_GC
elif [ $ge_option == true ]; then
  echo "Se ha seleccionado la opción -ge."
  funtion_GE
fi

if [ -n "$listaProg" ]; then
  echo "Lista de programa es $listaProg"
  programa $listaProg
fi
