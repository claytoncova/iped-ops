#!/bin/bash
# Script de automação de execução do IPED.
# Necessários os pacotes:
# - dialog (pacote para criação da interface)
# - tg-snd (script para envio de msg ao telegram)
# 
# Clayton G C Santos

#Necessário definir as referências e caminhos
IPED_PATH=""
OUTPUT_DIR="."
SHUTDOWN=false

#Testa se o caminho do IPED foi definido na variável IPED_PATH, acima.
if [ -z "$IPED_PATH" ]; then
	echo "Caminho para o .jar do IPED não encontrado no arquivo $0. Defina-o na variável IPED_PATH."
	exit 1
fi

display (){
        for file in $IPED_PATH/*.log; do [[ $file -nt $latest ]] && latest=$file; done
	tail -f $latest > out & 
	dialog --title "Saída do IPED: $latest" --tailbox out 0 0
}

#Função de criação de diretório com dados do item examinado. Apresenta erro para pastas já existentes.
create_dir () {
   mkdir "$OUTPUT_DIR/Of.${OFICIO[$1]}-Ld.${LAUDO[$1]}-${ITEM[$1]}-${SERIAL[$1]}"

   if [ $? -eq 1 ]; then
       dialog --title ' FALHA NA CRIAÇÃO DOS ARQUIVOS!! ' --msgbox 'Este item já foi extraído, verifique os parâmetros ou remova o diretório já existente.' 6 80
       exit 1
   fi       
} 

#Recebe a quantidade de iterações necessárias
qtd () {
   LOOPS=$( dialog --title 'IPED Ops' --stdout --inputbox 'Informe o número de discos a serem examinados:' 0 0 )
   return $LOOPS
}

#Para cada iteração, define os parâmetros para o item a ser examinado.
define () {
   ID[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'ID do Exame:' 0 0 )
   OFICIO[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Número do Ofício:' 0 0 )
   LAUDO[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Número do Laudo:' 0 0 )
   ITEM[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Item:' 0 0 )
   SERIAL[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Serial:' 0 0 )
   DISCO[$1]=$( dialog --title 'Automação de extração - IPED' --stdout --inputbox 'Disco:' 0 0 )
   MEM[$1]=$( dialog --stdout --menu 'Qtd. de Memória:' 0 0 0   4 GB 8 GB 12 GB )G
   
   #Checa se os parâmetros estão corretos, caso contrário reinicia o formulário
   dialog --title " Resumo do dados inseridos. " --yesno "Verifique se os dados abaixo estão corretos.\n Id. do Exame:${ID[$1]} \n Ofício:${OFICIO[$1]} \n Laudo:${LAUDO[$1]} \n Item:${ITEM[$1]} \n Serial:${SERIAL[$1]} \n Disco:${DISCO[$1]} \n Memória:${MEM[$1]}" --stdout 0 0 

   if [ $? -eq 0 ]; then
	return 0
   else
	define $1
   fi
}

#Executa o IPED enviando as mensagens de monitoramento para o telegram.
exec_iped () {
   tg-snd "Exame ${ID[$1]} Iniciado!"
   java -Xms4G -Xmx${MEM[$1]} -jar $IPED_PATH/iped.jar -d /dev/${DISCO[$1]} -o $OUTPUT_DIR/Of.${OFICIO[$1]}-Ld.${LAUDO[$1]}-${ITEM[$1]}-${SERIAL[$1]}/ &> /dev/null &
   PID_IPED=$!
   dialog --title 'Aguarde' --infobox '\nBuscando o arquivo de log...' 0 0 
   sleep 10
   display
   PID_DISPLAY=$!
   wait $PID_IPED
   kill -9 $PID_DISPLAY
   tg-snd "Exame ${ID[$1]} Finalizado!"
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
done
