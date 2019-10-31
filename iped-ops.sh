#!/bin/bash
# Script de automação de execução do IPED.
# Necessários os pacotes:
# - dialog (pacote para criação da interface)
# - tg-snd (script para envio de msg ao telegram)
# 
# Clayton G C Santos

#Necessário definir as referências e caminhos
SHUTDOWN=false

ID_STD="HD-Marca-Modelo"
OFICIO_STD="XX-19-DRACO-INTERIOR"
LAUDO_STD="XX-19"
SERIAL_STD=""
DISCO_STD="/dev/"




display (){
        for file in $IPED_PATH/log/*.log; do [[ $file -nt $latest ]] && latest=$file; done
	#tail -f $latest > out & 
	tail -f $latest & 
	#dialog --title "Saída do IPED: $latest" --tailbox out 0 0 &
        PID_DISPLAY=$!
        wait $1
        kill -9 $PID_DISPLAY
}

#Função de criação de diretório com dados do item examinado. Apresenta erro para pastas já existentes.
create_dir () {
   mkdir "$OUTPUT_DIR/Of.${OFICIO[$1]}-Ld.${LAUDO[$1]}-${ITEM[$1]}-${SERIAL[$1]}"

   if [ $? -eq 1 ]; then
       dialog --title ' Erro na criação dos arquivos!! ' --msgbox 'Falha no acesso ao diretório, inacessível ou anteriormente criado. ' 6 80
       exit 1
   fi       
} 

hash_dir () {
    tg-snd "Cálculo de hash ${ID[$1]} iniciado."
    cd "$OUTPUT_DIR/Of.${OFICIO[$1]}-Ld.${LAUDO[$1]}-${ITEM[$1]}-${SERIAL[$1]}"
    find . -type f -exec sha512sum "{}" \; 2>&1 | tee ../hashes-${LAUDO[$1]}.sha512
    mv ../hashes-${LAUDO[$1]}.sha512 ./hashes.sha512
    sha512sum hashes.sha512 > hash.txt
    tg-snd "Cálculo de hash ${ID[$1]} finalizado."
}

#Recebe a quantidade de iterações necessárias
qtd () {
   LOOPS=$( dialog --title 'IPED Ops' --stdout --inputbox 'ATENÇÃO: Informe o número de discos a serem examinados:' 0 0 )
   return $LOOPS
}

#Para cada iteração, define os parâmetros para o item a ser examinado.
define () {
   
   ID[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox "ID do $iº Exame:" 0 0 "$ID_STD")
   ID_STD=${ID[$1]}
   OFICIO[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Número do Ofício:' 0 0 "$OFICIO_STD")
   OFICIO_STD=${OFICIO[$1]}   
   LAUDO[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Número do Laudo:' 0 0 "$LAUDO_STD")
   LAUDO_STD=${LAUDO[$1]}
   ITEM[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Item:' 0 0 "${ID[$1]}")
   SERIAL[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Serial:' 0 0 "$SERIAL_STD")
   SERIAL_STD=${SERIAL[$1]}
   DISCO[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Disco:' 0 0 "$DISCO_STD" )
   MEM[$1]=$( dialog --stdout --menu 'Qtd. de Memória:' 0 0 0   12 GB 8 GB 4 GB )G
   
   #Checa se os parâmetros estão corretos, caso contrário reinicia o formulário
   dialog --title " Resumo do dados inseridos. " --yesno "Verifique se os dados abaixo estão corretos.\n Id. do $iº Exame:${ID[$1]} \n Ofício:${OFICIO[$1]} \n Laudo:${LAUDO[$1]} \n Item:${ITEM[$1]} \n Serial:${SERIAL[$1]} \n Disco:${DISCO[$1]} \n Memória:${MEM[$1]}" --stdout 0 0 

   if [ $? -eq 0 ]; then
	return 0
   else
	define $1
   fi
}

#Executa o IPED enviando as mensagens de monitoramento para o telegram.
exec_iped () {
   tg-snd "Extração ${ID[$1]} iniciada!"
   java -Xms4G -Xmx${MEM[$1]} -jar $IPED_PATH/iped.jar -d ${DISCO[$1]} -o $OUTPUT_DIR/Of.${OFICIO[$1]}-Ld.${LAUDO[$1]}-${ITEM[$1]}-${SERIAL[$1]}/ &> /dev/null &
   PID_IPED=$!
   dialog --title 'Aguarde' --infobox '\nBuscando o arquivo de log...' 0 0 
   sleep 10
   display $PID_IPED
   tg-snd "Extração ${ID[$1]} finalizada."
} 

#Define quantidade de iterações e executa a definição de parâmetros
qtd
loops=$?

for i in $(seq 1 $loops);do
   define i
done

#Cria os diretórios e executa o IPED para cada iteração
for i in $(seq 1 $loops);do
   create_dir i
   exec_iped i
   hash_dir i
done
tg-snd "Operação finalizada!!!"
