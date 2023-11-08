#!./ptbash

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
IS_G=false
IS_GC=false
IS_GE=false


##### Funciones #####

# Función para mostrar el menú de ayuda. 
USAGE() 
{
  echo "Usage: ./scdebug.sh  [-h] [-sto arg] [-v | -vall] [-k] [prog [arg …] ] [-nattch progtoattach …] [-pattch pid1 … ]" 
}

# Función para mostrar el segundo menú de ayuda. Este menú se muestra cuando 
# se cambia la bash a modo attach.
USAGE2() 
{
  echo "Usage: ./scdebug.sh [-h] [-k] -S commName prog [arg...]" 
}
# Función que se encarga de crear en segundo plano un proceso con el comando strace.
STRACE(){
  strace $stovar $@ 2>&1 | tee -a scdebug/$1/trace_$uuid.txt  
}

# Función que se encarga de comprobar si existe la carpeta scdebug y scdebug/$1, así como 
# qué procesos se están ejecutando.
CHECK(){
  if [ $# -ne 0 ]; then
    echo "La función 'prog' fue llamada con argumentos: $@"
  fi

  if [ -d "scdebug" ]; then 
    echo "La carpeta scdebug existe."
  else
    echo "La carpeta scdebug no existe."
    echo "mkdir scdebug"
    $(mkdir scdebug )
  fi

  if [ -d "scdebug/$1" ]; then 
    echo "La carpeta $1 existe."
  else
    echo "La carpeta $1 no existe."
    echo "mkdir scdebug/$1"
    $(mkdir scdebug/$1 )
  fi
}

# Función que se encarga de 
programa() {
  CHECK $1

  uuid=$(uuidgen)
  echo "strace $stovar -o scdebug/$1/trace_$uuid.txt $@" 
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

ejecutable_pattch(){
  strace $stovar -p $1 -o scdebug/$1/trace_$uidd.txt | tee -a scdebug/$1/trace_$uidd.txt # ejecutar el comando
}

# 
PATTCH(){
  CHECK $1
  uuid=$(uuidgen)
  ejecutable_pattch $1 &
}

# Función que se encarga de mostrar el último archivo de traza de un proceso. Comprueba la existencia 
# de la carpeta scdebug/, que la carpeta con el nombre del comando exista y muestra el último archivo de traza.
VISUALIZE(){
  DIRECTORY="scdebug/$1"

  if [ -d "$DIRECTORY" ]; then
    LAST_FILE=$(ls -t "$DIRECTORY" | head -1)
    
    if [ -n "$LAST_FILE" ]; then
      NEW_DATE=$(stat -c %y "$DIRECTORY/$LAST_FILE")

      echo "=============== ${TEXT_GREEN}COMMAND: $1 ${TEXT_RESET}============================================================="
      echo "=============== ${TEXT_GREEN}TRACE FILE: $LAST_FILE ${TEXT_RESET}================="
      echo "=============== ${TEXT_GREEN}TIME: $NEW_DATE ${TEXT_RESET}=================================="

      cat "$DIRECTORY/$LAST_FILE"
    else
      echo "${TEXT_RED}El directorio está vacío o no contiene archivos.${TEXT_RESET}"
    fi
  else
    echo "${TEXT_RED}El directorio $DIRECTORY no existe.${TEXT_RESET}"
  fi
}

# Función que se encarga de mostrar todos los archivos de traza de un proceso. Comprueba la existencia
# de la carpeta scdebug/, que la carpeta con el nombre del comando exista y muestra todos los archivos de traza.

VALL(){
  DIRECTORY="scdebug/$1"

  for FILE in "$DIRECTORY"/*; do
    if [ -f "$FILE" ]; then
      NEW_DATE=$(stat -c %y "$FILE")
      echo "=============== ${TEXT_GREEN}COMMAND: $1 ${TEXT_RESET}============================================================="
      echo "=============== ${TEXT_GREEN}TRACE FILE: $FILE ${TEXT_RESET}==="
      echo "=============== ${TEXT_GREEN}TIME: $NEW_DATE ${TEXT_RESET}=================================="

    fi
  done
}

# Función que se encarga de parar la ejecución de un proceso que se está siguiendo con strace.
STOP(){ 
  echo -n traced_$1 > /proc/$$/comm
  kill -SIGSTOP $$
  exec $listaProg

}

# Proceso hijo que se llama en la función G, para así poder ejecutar el comando strace en segundo plano.
CHILD_G(){
  strace -p $1 -o scdebug/$1/trace_$uuidd.txt /dev/null
}

G(){ 

  lista_g=$(ps | grep traced_ | tr -s ' ' | cut -d ' ' -f2 | tr -s '\n' ' ')

  for i in $lista_g; do
    CHECK $i
    uuid=$(uuidgen)
    CHILD_G $i &
    sleep 1
    kill -SIGCONT $i
  done

}

# Proceso hijo que se llama en la función GC, para así poder ejecutar el comando strace en segundo plano.
CHILD_GC(){
  TABLE=$(strace -p $1 -c -U name,max-time,total-time,calls -S max-time 2>&1)
  echo "$TABLE"

  echo "-------------------------"
  echo $(echo "$TABLE" | head -n 4 | tail -n 1)
  
}

GC(){

  lista_g=$(ps | grep traced_ | tr -s ' ' | cut -d ' ' -f2 | tr -s '\n' ' ')

  for i in $lista_g; do
    CHECK $i
    uuid=$(uuidgen)
    echo "${TEXT_GREEN}Proceso $i "
    CHILD_GC $i &
    echo "${TEXT_RESET}"
    echo "$TABLE"
    sleep 1
    kill -SIGCONT $i 
  done

}

# Proceso hijo que se llama en la función GE, para así poder ejecutar el comando strace en segundo plano.
CHILD_GE(){
  
  TABLE=$(strace -p $1 -c -U name,max-time,total-time,calls,errors -S errors 2>&1)
  echo "$TABLE"

  echo "-------------------------"
  echo $(echo "$TABLE" | head -n 4 | tail -n 1)
  
}

GE(){
  
  lista_g=$(ps | grep traced_ | tr -s ' ' | cut -d ' ' -f2 | tr -s '\n' ' ')

  for i in $lista_g; do
    CHECK $i
    uuid=$(uuidgen)
    echo "${TEXT_GREEN}Proceso $i "
    CHILD_GE $i &
    echo "${TEXT_RESET}"
    echo "$TABLE"
    sleep 1
    kill -SIGCONT $i 
  done
}

# En el caso de que no se pase ningún argumento, se muestra el menú de ayuda.
if [ $# -eq 0 ]; then
  echo "Debe añadir al menos un argumento."
  USAGE
  exit 1
fi

# Bucle para leer los argumentos pasados por teclado.
while [ "$1" != "" ]; do
    case $1 in
        -h )           
            USAGE
            exit
            ;;         
        -sto )   
          stovar="$2"
          echo "sto es $stovar"
          ;;   
        -nattch )  
          if [ "$2" == "" ]; then
          echo "Se esperaban argumentos para -nattch ( progtoattach1 ... ))"
            USAGE
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
            USAGE
            exit 1
          fi
          while [ "$2" != "-h" ] && [ "$2" != "prog" ] && [ "$2" != "-sto" ] && [ "$2" != "" ] && [ "$2" != "-nattch" ] && [ "$2" != "-k" ]; do
            PATTCH "$2"
            shift
          done
          ;;
        -v )
          if [ "$2" == "" ]; then
            echo "Se esperaban argumentos para -v ( prog1 ... ))"
            USAGE
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
              USAGE
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
            USAGE2
            exit 1
          fi
            STOP "$2"
            shift
          ;;
        -g )
          IS_G=true
          ;;
        -gc )
          IS_GC=true
          ;;
        -ge )
          IS_GE=true
          ;;

        * ) if [ "$READLIST" -ne 1 -a "$READPROG" -ne 2 ]; then
		      READPROG=1
		      listaProg+="$1 "
            elif [ "$READLIST" -eq 1 ]; then
                lista+="$1 "
            else
                echo "Argumento no reconocido: $1"
                USAGE
                exit 1
            fi
          ;;             
    esac
    shift
done

if [[ $IS_G == true && ($IS_GC == true || $IS_GE == true) ]] ||
   [[ $IS_GC == true && ($IS_G == true || $IS_GE == true) ]] ||
   [[ $IS_GE == true && ($IS_G == true || $IS_GC == true) ]]; then
  echo "Debes especificar sólo una de las opciones -g, -gc o -ge."
  USAGE
  exit 1
fi

if [ $IS_G == true ]; then
  echo "Se ha seleccionado la opción -g."
  G 
elif [ $IS_GC == true ]; then
  echo "Se ha seleccionado la opción -gc."
  GC
elif [ $IS_GE == true ]; then
  echo "Se ha seleccionado la opción -ge."
  GE
fi

if [ -n "$listaProg" ]; then
  echo "Lista de programa es $listaProg"
  programa $listaProg
else
  echo "No se ha especificado ningún programa."
  exit 1
fi
